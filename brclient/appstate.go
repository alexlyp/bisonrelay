package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/tls"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/companyzero/bisonrelay/brclient/internal/sloglinesbuffer"
	"github.com/companyzero/bisonrelay/brclient/internal/version"
	"github.com/companyzero/bisonrelay/client"
	"github.com/companyzero/bisonrelay/client/clientdb"
	"github.com/companyzero/bisonrelay/client/clientintf"
	"github.com/companyzero/bisonrelay/internal/strescape"
	"github.com/companyzero/bisonrelay/rpc"
	"github.com/companyzero/bisonrelay/zkidentity"
	"github.com/decred/dcrd/chaincfg/chainhash"
	"github.com/decred/dcrd/dcrutil/v4"
	"github.com/decred/dcrlnd/lnrpc"
	"github.com/decred/dcrlnd/lnwire"
	lpclient "github.com/decred/dcrlnlpd/client"
	"github.com/decred/go-socks/socks"
	"github.com/decred/slog"
	"github.com/muesli/reflow/wordwrap"
	"golang.org/x/exp/maps"
	"golang.org/x/text/collate"
	"golang.org/x/text/language"
)

type connState int

const (
	// The following as special markers for the active window.
	activeCWDiag   = -1             // diagnostic window (i.e. "win0")
	activeCWFeed   = -2             // feed window
	activeCWLog    = -3             // log window
	activeCWLndLog = -4             // lnd log window
	lastCWWindow   = activeCWLndLog // Must *ALWAYS* match the last item.

	connStateOffline connState = iota
	connStateCheckingWallet
	connStateOnline

	urlExchangeRate = "https://explorer.dcrdata.org/api/exchangerate"
)

type exchangeRate struct {
	DCRPrice float64 `json:"dcrPrice"`
	BTCPrice float64 `json:"btcPrice"`
}

type balance struct {
	total dcrutil.Amount
	conf  dcrutil.Amount
	recv  dcrutil.Amount
	send  dcrutil.Amount
}

type appState struct {
	ctx         context.Context
	cancel      func()
	wg          sync.WaitGroup
	c           *client.Client
	sendMsg     func(tea.Msg)
	logBknd     *logBackend
	log         slog.Logger
	lndLogLines *sloglinesbuffer.Buffer
	styles      *theme
	network     string
	isRestore   bool

	lnRPC      lnrpc.LightningClient
	httpClient *http.Client

	winW, winH int

	// History of commands.
	cmdHistoryFile *os.File
	workingCmd     string
	cmdHistory     []string
	cmdHistoryIdx  int

	// diagMsgs are the messages shown as a response to generic msgs,
	// displayed on window 0.
	diagMsgsMtx sync.Mutex
	diagMsgs    []string

	chatWindowsMtx sync.Mutex
	chatWindows    []*chatWindow
	activeCW       int
	prevActiveCW   int
	updatedCW      map[int]bool

	connectedMtx   sync.Mutex
	connected      connState
	serverAddr     string
	pushRate       uint64 // milliatoms / byte
	subRate        uint64 // milliatoms / byte
	expirationDays uint64

	// When written, this makes the next wallet check be skipped.
	skipWalletCheckChan chan struct{}

	minWalletBal dcrutil.Amount
	minRecvBal   dcrutil.Amount
	minSendBal   dcrutil.Amount

	canPayServerMtx      sync.Mutex
	canPayServer         bool
	canPayServerTestTime time.Time

	postsMtx   sync.Mutex
	posts      []clientdb.PostSummary
	post       *rpc.PostMetadata
	postSumm   clientdb.PostSummary
	myComments []string // Unreplicated comments
	postStatus []rpc.PostMetadataStatus

	contentMtx  sync.Mutex
	remoteFiles map[clientintf.UserID]map[clientdb.FileID]clientdb.RemoteFile
	progressMsg map[clientdb.FileID]*chatMsg

	qlenMtx sync.Mutex
	qlen    int

	// gcInvites tracks received gc invitations (gc name => invite id).
	gcInvitesMtx sync.Mutex
	gcInvites    map[string]uint64

	// Reply chans for notifications that require confirmation.
	clientIDChan      chan getClientIDReply
	lnOpenChannelChan chan msgLNOpenChannelReply
	lnRequestRecvChan chan msgLNRequestRecvReply
	lnFundWalletChan  chan msgLNFundWalletReply

	crashStackMtx sync.Mutex
	crashStack    string
	runErr        error

	// Footer data.
	footerMtx        sync.Mutex
	footerValid      bool
	footerLeft       string
	footerRight      string
	footerExtraRight string
	footerFull       string

	// balances
	balMtx sync.RWMutex
	bal    balance

	// exchange rate
	erMtx sync.RWMutex
	eRate exchangeRate

	setupMtx           sync.Mutex
	setupNeedsFunds    bool
	setupNeedsSendChan bool

	// window pinning on startup
	winpin []string

	// Collator for sorting strings for displaying.
	collator *collate.Collator

	mimeMap map[string]string

	// cmd to run when receiving messages. First element is bin, other are
	// args.
	bellCmd []string

	// missingKXUsers tracks when a gc msg was not sent to an user due to
	// being unkxd with them. The time is used so that this is only surfaced
	// in the UI at most once every 24h to avoid too much spam.
	missingKXUsersMtx sync.Mutex
	missingKXUsers    map[client.UserID]time.Time
}

type appStateErr struct {
	err error
}

func (as *appState) run() error {
	as.wg.Add(1)
	var err error
	go func() {
		as.log.Infof("Starting %s version %s", appName, version.String())
		err = as.c.Run(as.ctx)
		as.log.Debugf("as.c.Run() returned: %v", err)
		as.wg.Done()
	}()

	// Track outbound RMQ length.
	go func() {
		for {
			l := as.c.RMQLen()
			as.qlenMtx.Lock()
			changed := l != as.qlen
			as.qlen = l
			as.qlenMtx.Unlock()

			if changed {
				as.sendMsg(rmqLenChanged(l))
			}
			select {
			case <-time.After(100 * time.Millisecond):
			case <-as.ctx.Done():
				return
			}
		}
	}()

	go func() {
		for _, nick := range as.winpin {
			as.openChatWindow(nick)
		}
	}()

	go as.trackExchangeRate()
	go as.trackLNBalances()

	// Listen to lnd log lines.
	lndLogCb := as.lndLogLines.Listen(func(s string) { as.sendMsg(lndLogUpdated(s)) })

	// Update the time in footer every minute.
	go func() {
		for {
			now := time.Now().Truncate(time.Second)
			delta := time.Duration(60-now.Second()+1) * time.Second
			nextTick := time.After(delta)
			select {
			case <-as.ctx.Done():
				return
			case <-nextTick:
				as.sendMsg(currentTimeChanged{})
			}
			if time.Now().Day() != now.Day() {
				// Day changed.
				msg := fmt.Sprintf("Day changed to %s",
					time.Now().Format(ISO8601Date))
				as.chatWindowsMtx.Lock()
				for _, cw := range as.chatWindows {
					cw.newInternalMsg(msg)
				}
				as.chatWindowsMtx.Unlock()
				as.sendMsg(repaintActiveChat{})
			}
		}
	}()

	as.wg.Wait()
	if as.cmdHistoryFile != nil {
		as.cmdHistoryFile.Close()
	}

	// Stop listening to lnd log lines.
	lndLogCb.Close()

	as.log.Infof("App is exiting")
	return err
}

func (as *appState) exchangeRate() exchangeRate {
	as.erMtx.RLock()
	eRate := as.eRate
	as.erMtx.RUnlock()

	return eRate
}

func (as *appState) fetchExchangeRate(ctx context.Context) (exchangeRate, error) {
	var eRate exchangeRate
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		urlExchangeRate, nil)
	if err != nil {
		return eRate, fmt.Errorf("failed to create new http request: %v", err)
	}
	req.Header.Del("User-Agent")

	resp, err := as.httpClient.Do(req)
	if err != nil {
		return eRate, fmt.Errorf("failed to get exchange rate: %v", err)
	}
	b, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		return eRate, fmt.Errorf("failed to read exchange rate response: %v", err)
	}
	if err = json.Unmarshal(b, &eRate); err != nil {
		return eRate, fmt.Errorf("failed to decode exchange rate: %v", err)
	}
	return eRate, nil
}

func (as *appState) trackExchangeRate() {
	const shortTimeout = time.Second * 30
	const longTimeout = time.Minute * 10

	var timeout time.Duration
	for {
		select {
		case <-as.ctx.Done():
			return
		case <-time.After(timeout):
			eRate, err := as.fetchExchangeRate(as.ctx)
			if err != nil {
				as.log.Warnf("Unable to fetch exchange rate: %v", err)
				timeout = shortTimeout
			} else {
				as.erMtx.Lock()
				as.eRate = eRate
				as.erMtx.Unlock()

				timeout = longTimeout
			}
		}
	}
}

func (as *appState) trackLNBalances() {
	const shortTimeout = time.Second / 2
	const longTimeout = time.Second * 10
	var timeout time.Duration // Execute first check immediately
	var sameBalCount int
	var lastBal balance
	var checkedSetupNeeds bool
	var lastUnconf dcrutil.Amount
	for {
		select {
		case <-as.ctx.Done():
			return
		case <-time.After(timeout):
			// TODO
			if as.lnRPC == nil {
				continue
			}
			wallBalance, err := as.lnRPC.WalletBalance(as.ctx,
				&lnrpc.WalletBalanceRequest{})
			if err != nil {
				as.log.Errorf("Failed to get wallet balance: %v", err)
				continue
			}

			chanBalance, err := as.lnRPC.ChannelBalance(as.ctx, &lnrpc.ChannelBalanceRequest{})
			if err != nil {
				as.log.Errorf("Failed to get channel balance: %v", err)
				continue
			}
			as.balMtx.Lock()
			as.bal.total = dcrutil.Amount(wallBalance.TotalBalance)
			as.bal.conf = dcrutil.Amount(wallBalance.ConfirmedBalance)
			as.bal.recv = dcrutil.Amount(chanBalance.MaxInboundAmount)
			as.bal.send = dcrutil.Amount(chanBalance.MaxOutboundAmount)
			sameBal := as.bal.total == lastBal.total &&
				as.bal.recv == lastBal.recv &&
				as.bal.send == lastBal.send
			lastBal = as.bal
			as.balMtx.Unlock()

			// Deal with new unconfirmed funds or funds that were
			// confirmed.
			unconf := dcrutil.Amount(wallBalance.UnconfirmedBalance)
			if unconf > 0 && unconf != lastUnconf {
				as.sendMsg(msgUnconfirmedFunds(unconf))
			}
			if lastUnconf > 0 && unconf == 0 && wallBalance.ConfirmedBalance > 0 {
				as.sendMsg(msgConfirmedFunds(wallBalance.ConfirmedBalance))
			}
			lastUnconf = unconf

			if !checkedSetupNeeds {
				// Also check pending channels.
				hasPendingChans := false
				pendingChans, err := as.lnRPC.PendingChannels(as.ctx, &lnrpc.PendingChannelsRequest{})
				if err == nil {
					hasPendingChans = len(pendingChans.PendingOpenChannels) > 0
				}

				as.setupMtx.Lock()
				as.setupNeedsFunds = lastBal.conf == 0 && lastBal.send == 0
				as.setupNeedsSendChan = lastBal.send == 0 && !hasPendingChans
				as.setupMtx.Unlock()

				warnFunds := !as.isRestore && lastBal.total < as.minWalletBal
				warnSendChan := !as.isRestore && lastBal.send < as.minSendBal
				warnRecvChan := !as.isRestore && lastBal.recv < as.minRecvBal

				as.manyDiagMsgsCb(func(pf printf) {
					if warnFunds || warnSendChan || warnRecvChan {
						pf("")
					}
					if warnFunds {
						pf("Wallet balance is low -- run '/ln" +
							" newaddress' and send funds to the address")
					}
					if warnSendChan {
						pf("Send capacity is low -- run '/ln openchannel'")
					}
					if warnRecvChan {
						pf("Receive capacity is low -- run '/ln requestrecv'")
					}
				})

				checkedSetupNeeds = true
			}

			// Switch between from the short to the long
			// timeout if the balance isn't changing.
			if sameBal {
				sameBalCount += 1
			} else {
				sameBalCount = 0
				as.footerInvalidate()
				as.sendMsg(struct{}{})
			}
			useLongTimeout := sameBal && sameBalCount > 20
			if useLongTimeout {
				timeout = longTimeout
			} else {
				timeout = shortTimeout
			}
		}
	}

}

// storeCrash logs all currently executing goroutines to the app log and stores it as
// a crash stack. This will be dumped to stderr on program close.
func (as *appState) storeCrash() {
	stack := string(allStack())
	as.crashStackMtx.Lock()
	as.crashStack = stack
	as.crashStackMtx.Unlock()
	as.log.Infof("Full goroutine stack trace:\n%s", stack)
}

// getExitState returns the exit state of the app. The first return value is the
// crash stack, the second is the client run error.
func (as *appState) getExitState() (crashStack string, runErr error) {
	as.crashStackMtx.Lock()
	crashStack = as.crashStack
	runErr = as.runErr
	as.crashStackMtx.Unlock()
	return crashStack, runErr
}

func (as *appState) runAsCmd() tea.Msg {
	err := as.run()
	if err != nil {
		as.crashStackMtx.Lock()
		as.runErr = err
		as.crashStackMtx.Unlock()
		return appStateErr{err: err}
	}
	return nil
}

func (as *appState) currentConnState() connState {
	as.connectedMtx.Lock()
	st := as.connected
	as.connectedMtx.Unlock()
	return st
}

func (as *appState) serverPaymentRates() (uint64, uint64) {
	as.connectedMtx.Lock()
	push := as.pushRate
	sub := as.subRate
	as.connectedMtx.Unlock()
	return push, sub
}

// skipNextWalletCheck makes the next wallet check be skipped after connecting
// to the server. This blocks, so should be called from a goroutine.
func (as *appState) skipNextWalletCheck() {
	select {
	case as.skipWalletCheckChan <- struct{}{}:
	case <-as.ctx.Done():
	}
}

func (as *appState) lastLogLines(nbLines int) string {
	// TODO: This is inneficient. Improve to a streaming method.
	log := strings.Join(as.logBknd.lastLogLines(nbLines), "")
	log = wordwrap.String(log, as.winW-5)
	log = as.styles.help.Render(log)
	return log
}

func (as *appState) lastLndLogLines(nbLines int) string {
	log := strings.Join(as.lndLogLines.LastLogLines(nbLines), "")
	log = wordwrap.String(log, as.winW-5)
	log = as.styles.help.Render(log)
	return log
}

// errorLogMsg is called by the log backend when an error msg is received.
func (as *appState) errorLogMsg(msg string) {
	as.diagMsg(as.styles.err.Render(msg))
}

// diagMsg adds a message to be displayed in the diagnostic window (i.e. win0).
func (as *appState) diagMsg(format string, args ...interface{}) {
	as.manyDiagMsgsCb(func(pf printf) { pf(format, args...) })
}

type printf func(string, ...interface{})

// manyDiagMsgsCb calls `f` with a printf function that can be used to print
// multiple diagnostic lines at the same time without overlapping from other
// goroutines.
func (as *appState) manyDiagMsgsCb(f func(printf)) {
	pf := func(format string, args ...interface{}) {
		now := as.styles.timestamp.Render(time.Now().Format("15:04:05 "))
		line := now + fmt.Sprintf(format, args...)
		as.diagMsgs = append(as.diagMsgs, line)
	}
	as.diagMsgsMtx.Lock()
	f(pf)
	as.diagMsgsMtx.Unlock()

	as.chatWindowsMtx.Lock()
	if as.activeCW != activeCWDiag {
		as.updatedCW[activeCWDiag] = false
	}
	as.chatWindowsMtx.Unlock()

	as.footerInvalidate()
	as.sendMsg(repaintActiveChat{})
}

// getDiagMsgs renders the diagnotic messages (win0).
func (as *appState) getDiagMsgs() string {
	as.diagMsgsMtx.Lock()
	var b strings.Builder
	for _, m := range as.diagMsgs {
		b.WriteString(wordwrap.String(m, as.winW-2))
		b.WriteString("\n")
	}
	as.diagMsgsMtx.Unlock()
	return b.String()
}

// cwHelpMsgs prints help messages in the currently active window.
func (as *appState) cwHelpMsgs(f func(pf printf)) {
	as.chatWindowsMtx.Lock()
	switch {
	case as.activeCW == activeCWLog:
		as.chatWindowsMtx.Unlock()
		f(as.log.Infof)

	case as.activeCW == activeCWLndLog:
		as.chatWindowsMtx.Unlock()
		pf := func(format string, args ...interface{}) {
			as.lndLogLines.Write([]byte(fmt.Sprintf(format, args...)))
		}
		f(pf)

	case as.activeCW >= 0 && as.activeCW < len(as.chatWindows):
		cw := as.chatWindows[as.activeCW]
		as.chatWindowsMtx.Unlock()
		cw.manyHelpMsgs(f)

	default:
		as.chatWindowsMtx.Unlock()
		as.manyDiagMsgsCb(f)
	}

	as.sendMsg(repaintActiveChat{})
}

func (as *appState) cwHelpMsg(format string, args ...interface{}) {
	as.cwHelpMsgs(func(pf printf) { pf(format, args...) })
}

// activeWindowMsgs returns contents of the active window message (diag window,
// log window or a chat window).
func (as *appState) activeWindowMsgs() string {
	as.chatWindowsMtx.Lock()
	switch {
	case as.activeCW == activeCWDiag:
		as.chatWindowsMtx.Unlock()
		return as.getDiagMsgs()

	case as.activeCW == activeCWLog:
		as.chatWindowsMtx.Unlock()
		return as.lastLogLines(-1)

	case as.activeCW == activeCWLndLog:
		as.chatWindowsMtx.Unlock()
		return as.lastLndLogLines(-1)

	case as.activeCW == activeCWFeed:
		as.chatWindowsMtx.Unlock()
		return ""

	case as.activeCW < 0 || as.activeCW > len(as.chatWindows):
		// Unknown window.
		w := as.activeCW
		as.chatWindowsMtx.Unlock()
		return fmt.Sprintf("unknown window %d", w)
	}

	cw := as.chatWindows[as.activeCW]
	as.chatWindowsMtx.Unlock()
	msgs := cw.renderContent(as.winW, as.styles)
	return msgs
}

func (as *appState) rmqLen() int {
	as.qlenMtx.Lock()
	l := as.qlen
	as.qlenMtx.Unlock()
	return l
}

func (as *appState) closeActiveWindow() error {
	as.chatWindowsMtx.Lock()
	cw := as.activeCW
	if cw < 0 {
		as.chatWindowsMtx.Unlock()
		return fmt.Errorf("invalid window")
	}
	as.chatWindows = append(as.chatWindows[:cw:cw], as.chatWindows[cw+1:]...)

	// Decrement modified window notification for windows with id > cw. This
	// needs to be done in a sorted fashion to avoid overwriting.
	delete(as.updatedCW, cw)
	updatedIDs := maps.Keys(as.updatedCW)
	sort.Ints(updatedIDs)
	for _, id := range updatedIDs {
		if id < cw {
			continue
		}
		as.updatedCW[id-1] = as.updatedCW[id]
		delete(as.updatedCW, id)
	}

	as.chatWindowsMtx.Unlock()
	as.changeActiveWindowPrev()
	return nil
}

func (as *appState) markWindowSeen(win int) {
	as.chatWindowsMtx.Lock()
	delete(as.updatedCW, win)
	as.chatWindowsMtx.Unlock()
	as.footerInvalidate()
}

// getActiveWindow returns the current active window.
func (as *appState) changeActiveWindowNext() {
	// XXX race
	as.chatWindowsMtx.Lock()
	win := as.activeCW + 1
	as.chatWindowsMtx.Unlock()

	as.changeActiveWindow(win)
}

// getActiveWindow returns the current active window.
func (as *appState) changeActiveWindowPrev() {
	// XXX race
	as.chatWindowsMtx.Lock()
	win := as.activeCW - 1
	as.chatWindowsMtx.Unlock()

	as.changeActiveWindow(win)
}

// changeActiveWindowToPrevActive changes the active window to the previously
// active one.
func (as *appState) changeActiveWindowToPrevActive() {
	// XXX race
	as.chatWindowsMtx.Lock()
	win := as.prevActiveCW
	as.chatWindowsMtx.Unlock()

	as.changeActiveWindow(win)
}

// changeActiveWindow changes the state to the specified window.
func (as *appState) changeActiveWindow(win int) {
	as.chatWindowsMtx.Lock()
	defer as.chatWindowsMtx.Unlock()

	switch {
	case win >= lastCWWindow && win < len(as.chatWindows):
		// Valid window. Keep going.
	default:
		// Invalid window. Return.
		return
	}

	if win != as.activeCW {
		as.prevActiveCW = as.activeCW
	}

	// Remove from list of updated windows.
	delete(as.updatedCW, win)
	as.activeCW = win

	// Feed window is a top-level model.
	if win == activeCWFeed {
		as.sendMsg(showFeedWindow{})
		return
	}

	as.footerInvalidate()
	as.sendMsg(repaintActiveChat{})
}

// changeActiveWindowCW changes the currently active window to the passed one.
func (as *appState) changeActiveWindowCW(cw *chatWindow) {
	as.chatWindowsMtx.Lock()

	for i, w := range as.chatWindows {
		if w == cw {
			as.activeCW = i

			// Remove from list of updated windows.
			delete(as.updatedCW, i)

			break
		}
	}

	as.chatWindowsMtx.Unlock()
	as.footerInvalidate()
	as.sendMsg(repaintActiveChat{})
}

// isLogWinActive returns whether the log window is currently active.
func (as *appState) isLogWinActive() bool {
	as.chatWindowsMtx.Lock()
	active := as.activeCW == activeCWLog
	as.chatWindowsMtx.Unlock()
	return active
}

// isLndLogWinActive returns whether the lnd log window is currently active.
func (as *appState) isLndLogWinActive() bool {
	as.chatWindowsMtx.Lock()
	active := as.activeCW == activeCWLndLog
	as.chatWindowsMtx.Unlock()
	return active
}

// isFeedWinActive returns whether the feed window is currently active.
func (as *appState) isFeedWinActive() bool {
	as.chatWindowsMtx.Lock()
	active := as.activeCW == activeCWFeed
	as.chatWindowsMtx.Unlock()
	return active
}

// activeWinLabel returns the label for the currently active window as well as
// a list of updated inactive windows for display in the UI and an index of
// which wins have mentions.
func (as *appState) activeWinLabel() (string, []string, map[string]struct{}) {
	as.chatWindowsMtx.Lock()

	// Figure out active window.
	var label string
	switch {
	case as.activeCW == activeCWDiag:
		label = "0:console"

	case as.activeCW == activeCWLog:
		label = "log"

	case as.activeCW == activeCWLndLog:
		label = "lndlog"

	case as.activeCW == activeCWFeed:
		label = "feed"

	case as.activeCW >= 0 && as.activeCW < len(as.chatWindows):
		alias := as.chatWindows[as.activeCW].alias
		label = strconv.Itoa(as.activeCW+1) + ":" + alias
	}

	// List updated windows.
	updatedWins := make([]string, 0, len(as.updatedCW))
	mentionedWins := make(map[string]struct{})
	wins := make([]int, 0, len(as.updatedCW))
	for win := range as.updatedCW {
		wins = append(wins, win)
	}
	sort.Slice(wins, func(i, j int) bool { return wins[i] < wins[j] })
	for _, win := range wins {
		// +1 to maintain compat to legacy UX
		s := strconv.Itoa(win + 1)
		if win == activeCWFeed {
			s = "feed"
		}
		updatedWins = append(updatedWins, s)
		if as.updatedCW[win] {
			mentionedWins[s] = struct{}{}
		}
	}

	as.chatWindowsMtx.Unlock()
	return label, updatedWins, mentionedWins
}

// footerInvalidate marks the main app footer as invalid, causing the next
// footerView call to regenerate it.
func (as *appState) footerInvalidate() {
	as.footerMtx.Lock()
	as.footerValid = false
	as.footerMtx.Unlock()
}

// footerView returns the main window footer view.
func (as *appState) footerView(extraRight string) string {
	fs := as.styles.footer

	// Helper that rebuilds and returns the full footer based on the left
	// and right messages.
	getFullFooter := func() string {
		as.footerExtraRight = extraRight

		leftMsg := as.footerLeft
		rightMsg := as.footerExtraRight + as.footerRight
		spaces := fs.Render(strings.Repeat(" ",
			max(0, as.winW-lipgloss.Width(leftMsg+rightMsg))))

		as.footerFull = leftMsg + spaces + rightMsg
		as.footerValid = true
		return as.footerFull
	}

	as.footerMtx.Lock()
	defer as.footerMtx.Unlock()

	// A valid footer means none of the footer info changed, so safe to
	// reuse the cached footer.
	if as.footerValid {
		if as.footerRight != extraRight {
			return getFullFooter()
		}
		return as.footerFull
	}

	// Rebuild entire footer.
	activeWin, updatedWins, mentionedWins := as.activeWinLabel()
	updated := fs.Render("[")
	for i, win := range updatedWins {
		if i > 0 {
			updated += fs.Render(",")
		}
		style := fs
		if _, ok := mentionedWins[win]; ok {
			style = as.styles.footerMention
		}
		updated += style.Render(win)
	}
	updated += fs.Render("] ")

	prevFG := fs.GetForeground()
	warnFG, _ := textToColor("yellow")
	total, recv, send := as.channelBalance()

	balance := fs.Render(" [wallet: ")
	if total < as.minWalletBal {
		balance += fs.Foreground(warnFG).Render(fmt.Sprintf("%.8f", total.ToCoin()))
		fs.Foreground(prevFG)
	} else {
		balance += fs.Render(fmt.Sprintf("%.8f", total.ToCoin()))
	}
	balance += fs.Render(" recv:")
	if recv < as.minRecvBal {
		balance += fs.Foreground(warnFG).Render(fmt.Sprintf("%.8f", recv.ToCoin()))
		fs.Foreground(prevFG)
	} else {
		balance += fs.Render(fmt.Sprintf("%.8f", recv.ToCoin()))
	}
	balance += fs.Render(" send:")
	if send < as.minSendBal {
		balance += fs.Foreground(warnFG).Render(fmt.Sprintf("%.8f", send.ToCoin()))
		fs.Foreground(prevFG)
	} else {
		balance += fs.Render(fmt.Sprintf("%.8f", send.ToCoin()))
	}
	balance += fs.Render("]")

	as.footerLeft = fs.Render(fmt.Sprintf(
		" [%s] [%s] [%s] %s",
		time.Now().Format("15:04"),
		as.c.LocalNick(),
		activeWin,
		updated,
	))
	as.footerRight = balance
	return getFullFooter()
}

// findOrNewGCWindow finds the existing chat window for the given gc or creates
// a new one with the given alias.
func (as *appState) findOrNewGCWindow(gcID zkidentity.ShortID) *chatWindow {
	gcName, err := as.c.GetGCAlias(gcID)
	if err != nil {
		gcName = gcID.String()
	}

	as.chatWindowsMtx.Lock()
	for _, cw := range as.chatWindows {
		if cw.isGC && cw.gc == gcID {
			as.chatWindowsMtx.Unlock()
			return cw
		}
	}

	cw := &chatWindow{
		alias: gcName,
		isGC:  true,
		gc:    gcID,
		me:    as.c.LocalNick(),
	}
	cw.newInternalMsg("First message received")
	as.chatWindows = append(as.chatWindows, cw)
	as.updatedCW[len(as.chatWindows)-1] = false
	as.chatWindowsMtx.Unlock()

	as.footerInvalidate()
	as.diagMsg("Started Group Chat %s", gcName)
	return cw
}

// findOrNewChatWindow finds the existing chat window for the given user or
// creates a new one with the given alias.
func (as *appState) findOrNewChatWindow(id clientintf.UserID, alias string) *chatWindow {
	as.chatWindowsMtx.Lock()
	for _, cw := range as.chatWindows {
		if cw.uid == id {
			as.chatWindowsMtx.Unlock()
			return cw
		}
	}

	cw := &chatWindow{
		uid:   id,
		alias: alias,
		me:    as.c.LocalNick(),
	}
	as.chatWindows = append(as.chatWindows, cw)
	as.updatedCW[len(as.chatWindows)-1] = false
	as.chatWindowsMtx.Unlock()

	as.footerInvalidate()
	as.diagMsg("Started chat with %s", alias)
	return cw
}

// findChatWindow finds the existing chat window for the given user. Returns nil
// if the chat window is not setup.
func (as *appState) findChatWindow(id clientintf.UserID) *chatWindow {
	as.chatWindowsMtx.Lock()
	for _, cw := range as.chatWindows {
		if cw.uid == id {
			as.chatWindowsMtx.Unlock()
			return cw
		}
	}
	as.chatWindowsMtx.Unlock()

	return nil
}

// openChatWindow opens (or creates) the chat window of the specified nick
// or textual id. This handles both PMs and GCs.
func (as *appState) openChatWindow(nick string) error {
	var cw *chatWindow
	if ru, err := as.c.UserByNick(nick); err == nil {
		// It's a nick/uid.
		cw = as.findOrNewChatWindow(ru.ID(), ru.Nick())
	} else {
		gcID, err := as.c.GCIDByName(nick)
		if err == nil {
			if _, err = as.c.GetGC(gcID); err == nil {
				// It's a gc.
				cw = as.findOrNewGCWindow(gcID)
			}
		}
	}
	if cw == nil {
		return fmt.Errorf("nick or gc %q not found", nick)
	}
	if cw.empty() {
		cw.newInternalMsg(fmt.Sprintf("Conversation Started %s",
			time.Now().Format(ISO8601Date)))
	}
	as.changeActiveWindowCW(cw)
	return nil
}

// repaintIfActiveWithMention sends a msg to the UI to repaint the current
// window if the current window is the specified window.
//
// If mentioned is specified, the window is noted as updated with a local user
// mention.
func (as *appState) repaintIfActiveWithMention(cw *chatWindow, mentioned bool) {
	as.chatWindowsMtx.Lock()
	active := as.activeCW >= 0 && len(as.chatWindows) > as.activeCW &&
		as.chatWindows[as.activeCW] == cw
	if !active {
		// Track this window as updated.
		for i := range as.chatWindows {
			if as.chatWindows[i] == cw {
				if _, ok := as.updatedCW[i]; !ok || mentioned {
					as.updatedCW[i] = mentioned
				}
				break
			}
		}
	}
	as.chatWindowsMtx.Unlock()

	as.footerInvalidate()
	if active {
		as.sendMsg(repaintActiveChat{})
	} else {
		as.sendMsg(struct{}{}) // force update footer
	}
}

// repaintIfActive see repaintIfActiveWithMention.
func (as *appState) repaintIfActive(cw *chatWindow) {
	as.repaintIfActiveWithMention(cw, false)
}

// handleRcvdText does some improvements to a raw received message (escapes,
// handles mentions, etc).
func (as *appState) handleRcvdText(s string, nick string) string {
	// Escape msg to avoid bad things.
	s = strescape.Content(s)

	// Cannonicalize line endings.
	s = strescape.CannonicalizeNL(s)

	if len(as.bellCmd) > 0 && as.bellCmd[0] == "*BEEP*" {
		os.Stdout.Write([]byte("\a"))
	} else if len(as.bellCmd) > 0 {
		go func() {
			cmd := append([]string{}, as.bellCmd...)
			msg := s[:min(len(s), 100)] // truncate msg passed to cmd.

			// Replace $src and $msg in command line args.
			for i := 1; i < len(cmd); i++ {
				cmd[i] = strings.Replace(cmd[i], "$src", nick, -1)
				cmd[i] = strings.Replace(cmd[i], "$msg", msg, -1)
			}

			c := exec.Command(cmd[0], cmd[1:]...)
			c.Stdout = nil
			c.Stderr = nil
			err := c.Start()
			if err != nil {
				as.diagMsg("Unable to run bellcmd: %v", err)
			}
		}()
	}

	return s
}

// writeInvite writes a new invite to the given filename. This blocks until the
// invite is written.
func (as *appState) writeInvite(filename string) {
	as.cwHelpMsg("Attempting to create and subscribe to new invite")
	w := new(bytes.Buffer)
	pii, err := as.c.WriteNewInvite(w)
	if err != nil {
		as.cwHelpMsg("Unable to create invite: %v", err)
		return
	}

	err = os.WriteFile(filename, w.Bytes(), 0o700)
	if err != nil {
		as.cwHelpMsg("Unable to write invite file: %v", err)
		return
	}

	as.cwHelpMsg("Created invite at RV %s", pii.InitialRendezvous)
	as.cwHelpMsg("Send file %q to other client and type /add %s",
		filename, filepath.Base(filename))
}

// pm sends the given pm message in the specified window. Blocks until the
// messsage is sent to the server.
func (as *appState) pm(cw *chatWindow, msg string) {
	m := cw.newUnsentPM(msg)
	as.repaintIfActive(cw)

	var err error
	var progrChan chan client.SendProgress
	if cw.isGC {
		progrChan = make(chan client.SendProgress)
		err = as.c.GCMessage(cw.gc, msg, rpc.MessageModeNormal, progrChan)
	} else {
		err = as.c.PM(cw.uid, msg)
	}
	if err != nil {
		if cw.isGC {
			as.cwHelpMsg("Unable to send message to GC %q: %v",
				cw.alias, err)
		} else {
			as.cwHelpMsg("Unable to send PM to %q: %v",
				cw.alias, err)
		}
	} else if progrChan == nil {
		cw.setMsgSent(m)
		as.sendMsg(repaintActiveChat{})
	} else {
		for progr := range progrChan {
			if progr.Err != nil {
				as.diagMsg("Error while sending GC msg: %v", progr.Err)
			}
			as.log.Debugf("Progress on GC Message %d/%d",
				progr.Sent, progr.Total)
			if progr.Sent == progr.Total {
				cw.setMsgSent(m)
				as.sendMsg(repaintActiveChat{})
				break
			}
		}
	}
}

// payTip sends a tip to the user of the given window. This blocks until the
// tip has been paid.
func (as *appState) payTip(cw *chatWindow, dcrAmount float64) {
	m := cw.newInternalMsg(fmt.Sprintf("Sending %.8f DCR as tip", dcrAmount))
	as.repaintIfActive(cw)
	err := as.c.TipUser(cw.uid, dcrAmount)
	if err != nil {
		as.cwHelpMsg("Unable to tip user %q: %v",
			cw.alias, err)
	} else {
		cw.setMsgSent(m)
		as.repaintIfActive(cw)
	}
}

// block blocks a user.
func (as *appState) block(cw *chatWindow, uid clientintf.UserID) {
	m := cw.newInternalMsg("Blocked user")
	as.repaintIfActive(cw)
	err := as.c.Block(cw.uid)
	if err != nil {
		as.cwHelpMsg("Unable to block user %q: %v",
			cw.alias, err)
	} else {
		cw.setMsgSent(m)
		as.repaintIfActive(cw)
	}
}

// inviteToGC invites the given user to the GC in the specified window. Blocks
// until the invite message is sent to the server.
func (as *appState) inviteToGC(cw *chatWindow, nick string, uid clientintf.UserID) {
	m := cw.newUnsentPM(fmt.Sprintf("Invited user %q to gc %s", nick, cw.alias))
	as.repaintIfActive(cw)
	err := as.c.InviteToGroupChat(cw.gc, uid)
	if err == nil {
		cw.setMsgSent(m)
		as.repaintIfActive(cw)
	} else {
		as.diagMsg("Unable to invite %q to gc %q: %v", nick, cw.gc.String(), err)
	}
}

// kickFromGC kicks the given user from the given GC. Only works if we're the
// admin of the GC.
func (as *appState) kickFromGC(gcWin *chatWindow, uid clientintf.UserID,
	userNick, reason string) {

	gcName := gcWin.alias
	err := as.c.GCKick(gcWin.gc, uid, reason)
	if err == nil {
		gcWin.newInternalMsg(fmt.Sprintf("Kicking user %s from gc %s",
			userNick, gcName))
		as.repaintIfActive(gcWin)
	} else {
		as.cwHelpMsg("Unable to kick %s from gc %q: %v", userNick,
			gcName, err)
	}
}

// partFromGC withdraws the local user from the GC.
func (as *appState) partFromGC(gcWin *chatWindow, reason string) {
	gcName := gcWin.alias
	m := gcWin.newInternalMsg("Parting from GC...")
	as.repaintIfActive(gcWin)
	err := as.c.PartFromGC(gcWin.gc, reason)
	if err == nil {
		gcWin.setMsgSent(m)
		as.repaintIfActive(gcWin)
	} else {
		as.cwHelpMsg("Unable to part from gc %q: %v", gcName, err)
	}
}

// killGC dissolves the given GC.
func (as *appState) killGC(gcWin *chatWindow, reason string) {
	gcName := gcWin.alias
	err := as.c.KillGroupChat(gcWin.gc, reason)
	if err == nil {
		gcWin.newInternalMsg("Killed GC")
		as.repaintIfActive(gcWin)
	} else {
		as.cwHelpMsg("Unable to kill GC %q: %v", gcName, err)
	}
}

// listUserContent lists the contents of the given user's dir.
func (as *appState) listUserContent(cw *chatWindow, dir, filter string) {
	withFilter := ""
	if filter != "" {
		withFilter = "with filter " + filter
	}
	m := cw.newInternalMsg(fmt.Sprintf("Listing user files in dir %q%s", dir, withFilter))
	as.repaintIfActive(cw)
	err := as.c.ListUserContent(cw.uid, []string{dir}, filter)
	if err != nil {
		as.diagMsg("Unable to list user content: %v", err)
		return
	}
	cw.setMsgSent(m)
	as.repaintIfActive(cw)
}

func (as *appState) getUserContent(cw *chatWindow, filename string) {
	var rf clientdb.RemoteFile
	var fid, emptyFID clientdb.FileID

	// If `filename` is a file ID, use that directly, otherwise try to find
	// the file id of a file we know the user has.
	if err := fid.FromString(filename); err != nil {
		fid = emptyFID
		as.contentMtx.Lock()
		if userFiles, ok := as.remoteFiles[cw.uid]; ok {
			for id, file := range userFiles {
				if file.Metadata.Filename == filename {
					fid = id
					rf = file
					break
				}
			}
		}
		as.contentMtx.Unlock()
	}

	if fid == emptyFID {
		as.cwHelpMsg("Cannot find file ID for file %q. Try `/ft ls <user>` first.",
			filename)
		return
	}

	if rf.DiskPath != "" {
		if _, err := os.Stat(rf.DiskPath); err == nil {
			as.cwHelpMsg("File already downloaded in %q", rf.DiskPath)
			return
		}
	}

	err := as.c.GetUserContent(cw.uid, fid)
	if err != nil {
		as.cwHelpMsg("Unable to fetch user content: %v", err)
	}
	as.cwHelpMsg(fmt.Sprintf("Starting to download file %s", filename))
	as.repaintIfActive(cw)
}

func (as *appState) subscribeToPosts(cw *chatWindow) {
	m := cw.newInternalMsg("Subscribing to posts")
	as.repaintIfActive(cw)
	err := as.c.SubscribeToPosts(cw.uid)
	if err != nil {
		as.diagMsg("Unable to subscribe to posts: %v", err)
		return
	}
	cw.setMsgSent(m)
	as.log.Debugf("Subscribed to posts from %q", cw.alias)
	as.repaintIfActive(cw)
}

func (as *appState) unsubscribeToPosts(cw *chatWindow) {
	m := cw.newInternalMsg("Unsubscribing to posts")
	as.repaintIfActive(cw)
	err := as.c.UnsubscribeToPosts(cw.uid)
	if err != nil {
		as.diagMsg("Unable to unsubscribe to posts: %v", err)
		return
	}
	cw.setMsgSent(m)
	as.log.Debugf("Unsubscribed to posts from %q", cw.alias)
	as.repaintIfActive(cw)
}

func (as *appState) requestRatchetReset(cw *chatWindow) {
	m := cw.newInternalMsg("Requesting ratchet reset")
	as.repaintIfActive(cw)
	err := as.c.ResetRatchet(cw.uid)
	if err != nil {
		as.diagMsg("Unable to request ratchet reset: %v", err)
		return
	}
	cw.setMsgSent(m)
	as.repaintIfActive(cw)
}

func (as *appState) requestMediateID(cw *chatWindow, target clientintf.UserID) {
	m := cw.newInternalMsg(fmt.Sprintf("Requesting mediate identity with %s", target))
	as.repaintIfActive(cw)
	err := as.c.RequestMediateIdentity(cw.uid, target)
	if err != nil {
		as.diagMsg("Unable to request mediate identity: %v", err)
		return
	}
	cw.setMsgSent(m)
	as.repaintIfActive(cw)
}

func (as *appState) requestTransReset(mediator, target *chatWindow) {
	mMediator := mediator.newInternalMsg(fmt.Sprintf("Requesting trans reset with %s",
		target.alias))
	mTarget := target.newInternalMsg(fmt.Sprintf("Requesting %s to trans reset with this user",
		mediator.alias))
	as.repaintIfActive(mediator)
	as.repaintIfActive(target)
	err := as.c.RequestTransitiveReset(mediator.uid, target.uid)
	if err != nil {
		as.diagMsg("Unable to request trans reset: %v", err)
		return
	}
	mediator.setMsgSent(mMediator)
	target.setMsgSent(mTarget)
	as.repaintIfActive(mediator)
	as.repaintIfActive(target)
}

// postAuthorRelayer returns the nick of the author and relayer (if different
// than the author) for the given post.
func (as *appState) postAuthorRelayer(post clientdb.PostSummary) (string, string) {
	me := as.c.PublicID()
	author := "me"
	authorMe := post.AuthorID == me
	if !authorMe {
		// See if we know author.
		ru, err := as.c.UserByID(post.AuthorID)
		if err != nil {
			// We don't know author. Use nick on post or raw id.
			author = strescape.Nick(strings.TrimSpace(post.AuthorNick))
			if author == "" {
				author = fmt.Sprintf("id:%s", hex.EncodeToString(post.From[:8]))
			}
		} else {
			if ru.IsIgnored() {
				author = "(ignored)"
			} else {
				author = strescape.Nick(ru.Nick())
			}
		}
	}

	var relayedBy string
	if post.From != post.AuthorID {
		relayedBy = "me"
		if post.From != me {
			ru, err := as.c.UserByID(post.From)
			if err == nil {
				// We know who relayed.
				relayedBy = strescape.Nick(ru.Nick())
			} else {
				// We don't know who relayed.
				relayedBy = fmt.Sprintf("id:%s", hex.EncodeToString(post.From[:8]))
			}
		}
	}

	return author, relayedBy
}

func (as *appState) openChannel(amount, key, server string) error {
	if key == "" {
		return usageError{msg: "pubkey cannot be empty"}
	}
	if amount == "" {
		return usageError{msg: "funding amount cannot be empty"}
	}
	npk, err := hex.DecodeString(key)
	if err != nil {
		return fmt.Errorf("unable to decode pubkey: %w", err)
	}
	fundingF, err := strconv.ParseFloat(amount, 64)
	if err != nil {
		return err
	}
	fundingAmt, err := dcrutil.NewAmount(fundingF)
	if err != nil {
		return err
	}

	// Check if connecting to the node was successful.
	// We discard the peer id returned as it is not needed.
	req := &lnrpc.ConnectPeerRequest{
		Addr: &lnrpc.LightningAddress{
			Pubkey: key,
			Host:   server,
		},
		Perm: false,
	}
	_, err = as.lnRPC.ConnectPeer(as.ctx, req)
	if err != nil &&
		!strings.Contains(err.Error(), "already connected") {
		return err
	}

	ocr := lnrpc.OpenChannelRequest{
		NodePubkey:         npk,
		LocalFundingAmount: int64(fundingAmt),
		PushAtoms:          0,
	}
	res, err := as.lnRPC.OpenChannelSync(as.ctx, &ocr)
	if err != nil {
		return err
	}
	as.cwHelpMsg("Opening LN channel %s of size %s", chanPointToStr(res),
		fundingAmt)
	return nil

}

// closeChannel attempts to close the specified channel. This blocks until the
// channel is closed, so must be called from a goroutine.
func (as *appState) closeChannel(chanPoint *lnrpc.ChannelPoint, force bool) {
	req := &lnrpc.CloseChannelRequest{
		ChannelPoint: chanPoint,
		Force:        force,
	}

	res, err := as.lnRPC.CloseChannel(as.ctx, req)
	if err != nil {
		as.cwHelpMsg("Unable to close channel: %v", err)
		return
	}

	for {
		updt, err := res.Recv()
		if err != nil {
			as.diagMsg("Error reading channel close update: %v", err)
			return
		}

		if updt, ok := updt.Update.(*lnrpc.CloseStatusUpdate_ClosePending); ok {
			ch, _ := chainhash.NewHash(updt.ClosePending.Txid)
			as.diagMsg("Channel %s close pending on tx %s:%d",
				chanPointToStr(chanPoint), ch,
				updt.ClosePending.OutputIndex)
		}
		if updt, ok := updt.Update.(*lnrpc.CloseStatusUpdate_ChanClose); ok {
			ch, _ := chainhash.NewHash(updt.ChanClose.ClosingTxid)
			as.diagMsg("Channel %s closed on tx %s",
				chanPointToStr(chanPoint), ch)
			break
		}
	}
}

// requestRecv returns when an error happens up until the stage where the
// channel is pending.
func (as *appState) requestRecv(amount, server, key string, caCert []byte) error {
	chanF, err := strconv.ParseFloat(amount, 64)
	if err != nil {
		return err
	}
	chanAmt, err := dcrutil.NewAmount(chanF)
	if err != nil {
		return err
	}
	chanSize := uint64(chanAmt)
	pendingChan := make(chan struct{})
	lpcfg := lpclient.Config{
		LC:           as.lnRPC,
		Address:      server,
		Key:          key,
		Certificates: caCert,

		PolicyFetched: func(policy lpclient.ServerPolicy) error {
			estInvoice := lpclient.EstimatedInvoiceAmount(chanSize,
				policy.ChanInvoiceFeeRate)
			as.log.Infof("Fetched server policy for chan of size %d."+
				" Estimated Invoice amount: %s", chanAmt,
				dcrutil.Amount(estInvoice))
			as.log.Debugf("Full server policy: %#v", policy)
			msg := lnReqRecvConfirmPayment{
				chanSize:        chanSize,
				policy:          policy,
				estimatedAmount: estInvoice,
				replyChan:       make(chan bool, 1),
			}

			// Send message to UI to confirm payment.
			as.sendMsg(msg)

			// Wait for UI confirmation.
			select {
			case <-as.ctx.Done():
				return as.ctx.Err()
			case <-time.After(time.Minute):
				return fmt.Errorf("user timed out confirming liquidity request")
			case res := <-msg.replyChan:
				if res {
					return nil
				}
				return fmt.Errorf("user canceled liquidity request")
			}
		},

		PayingInvoice: func(payHash string) {
			as.log.Infof("Paying for invoice %s", payHash)
		},

		InvoicePaid: func() {
			as.log.Infof("Invoice paid. Waiting for channel to be opened")
		},

		PendingChannel: func(channelPoint string, capacity uint64) {
			as.log.Infof("Detected new pending channel %s with LP node with capacity %s",
				channelPoint, dcrutil.Amount(capacity))
			as.cwHelpMsg("Liquidity Provider opened channel %s with %s",
				channelPoint, dcrutil.Amount(capacity))
			close(pendingChan)
		},
	}
	c, err := lpclient.New(lpcfg)
	if err != nil {
		return err
	}

	// Wait until either the new channel is pending or an error happens.
	errChan := make(chan error, 1)
	go func() {
		errChan <- c.RequestChannel(as.ctx, chanSize)
	}()
	select {
	case err := <-errChan:
		return err
	case <-pendingChan:
		return nil
	}
}

func (as *appState) createPost(post string) {
	as.loadPosts()
	summ, err := as.c.CreatePost(post, "")
	if err != nil {
		as.cwHelpMsg("Unable to create post: %v", err)
	} else {
		as.cwHelpMsg("Created post %s", summ.ID)
		as.postsMtx.Lock()
		as.posts = append(as.posts, summ)
		as.postsMtx.Unlock()
		as.sendMsg(summ)
	}
}

func (as *appState) loadPosts() {
	posts, err := as.c.ListPosts()
	if err != nil {
		as.cwHelpMsg("Unable to load posts: %v", err)
	} else {
		as.postsMtx.Lock()
		as.posts = posts
		as.postsMtx.Unlock()
	}
}

func (as *appState) allPosts() []clientdb.PostSummary {
	as.postsMtx.Lock()
	res := as.posts
	as.postsMtx.Unlock()
	return res
}

func (as *appState) activePost() (rpc.PostMetadata, clientdb.PostSummary,
	[]rpc.PostMetadataStatus, []string) {

	var res rpc.PostMetadata
	as.postsMtx.Lock()
	if as.post != nil {
		res = *as.post
	}
	summ := as.postSumm
	status := as.postStatus
	myComments := as.myComments
	as.postsMtx.Unlock()

	return res, summ, status, myComments
}

func (as *appState) activatePost(summ *clientdb.PostSummary) {
	post, err := as.c.ReadPost(summ.From, summ.ID)
	if err != nil {
		as.diagMsg("Cannot load post: %v", err)
		return
	}
	postStatus, err := as.c.ListPostStatusUpdates(summ.From, summ.ID)
	if err != nil {
		as.diagMsg("Cannot load post status: %v", err)
		return
	}
	as.postsMtx.Lock()
	as.post = &post
	as.postSumm = *summ
	as.postStatus = postStatus
	as.postsMtx.Unlock()
}

func (as *appState) commentPost(from clientintf.UserID, pid clientintf.PostID,
	comment string, parentComment *clientintf.ID) {

	as.postsMtx.Lock()
	as.myComments = append(as.myComments, comment)
	as.postsMtx.Unlock()
	as.sendMsg(sentPostComment{})

	err := as.c.CommentPost(from, pid, comment, parentComment)
	if err != nil {
		as.diagMsg("Unable to comment post: %v", err.Error())
	}
}

func (as *appState) getUserPost(cw *chatWindow, pid clientintf.PostID) {
	cw.newInternalMsg(fmt.Sprintf("Fetching post %s", pid))
	as.repaintIfActive(cw)
	err := as.c.GetUserPost(cw.uid, pid, true)
	if err != nil {
		cw.newInternalMsg(fmt.Sprintf("Unable to fetch user post: %v", err))
		as.repaintIfActive(cw)
	}
}

func (as *appState) relayPost(fromUID clientintf.UserID, pid clientintf.PostID,
	cw *chatWindow) {
	cw.newInternalMsg(fmt.Sprintf("Relaying post %s from %s", pid, fromUID))
	as.repaintIfActive(cw)
	err := as.c.RelayPost(fromUID, pid, cw.uid)
	if err != nil {
		cw.newInternalMsg(fmt.Sprintf("Unable to relay post: %v", err))
		as.repaintIfActive(cw)
	}
}

func (as *appState) relayPostToAll(fromUID clientintf.UserID, pid clientintf.PostID) {
	as.diagMsg(fmt.Sprintf("Relaying post %s from %s", pid, fromUID))
	err := as.c.RelayPostToSubscribers(fromUID, pid)
	if err != nil {
		as.diagMsg("Unable to relay post: %v", err)
	}
}

func (as *appState) queryLNNodeInfo(nodePubKey string, amount uint64) error {
	if as.lnRPC == nil {
		return fmt.Errorf("LN client not configured")
	}

	nodeInfoReq := &lnrpc.NodeInfoRequest{
		PubKey:          nodePubKey,
		IncludeChannels: true,
	}
	nodeInfoRes, nodeInfoErr := as.lnRPC.GetNodeInfo(as.ctx, nodeInfoReq)

	routeReq := &lnrpc.QueryRoutesRequest{
		PubKey:   nodePubKey,
		Amt:      int64(amount),
		FeeLimit: client.PaymentFeeLimit(amount * 1000),
	}
	route, routeErr := as.lnRPC.QueryRoutes(as.ctx, routeReq)

	as.cwHelpMsgs(func(pf printf) {
		pf("")
		pf("LN Node Info: %s", nodePubKey)
		if nodeInfoErr != nil {
			pf("Unable to query node info: %v", nodeInfoErr)
		} else {
			pf("Num Channels %d   Total Capacity: %.8f",
				nodeInfoRes.NumChannels,
				float64(nodeInfoRes.TotalCapacity)/1e8)
			pf("Channels")
			for _, ch := range nodeInfoRes.Channels {
				pf("  %.8f - %s - %s",
					float64(ch.Capacity)/1e8, ch.ChanPoint,
					lnwire.NewShortChanIDFromInt(ch.ChannelId))
				node1dis := "✓"
				if ch.Node1Policy == nil {
					node1dis = "⨂"
				} else if ch.Node1Policy.Disabled {
					node1dis = "✗"
				}
				node2dis := "✓"
				if ch.Node2Policy == nil {
					node2dis = "⨂"
				} else if ch.Node2Policy.Disabled {
					node2dis = "✗"
				}
				var node1time, node2time time.Time
				if ch.Node1Policy != nil {
					node1time = time.Unix(int64(ch.Node1Policy.LastUpdate), 0)
				}
				if ch.Node2Policy != nil {
					node2time = time.Unix(int64(ch.Node2Policy.LastUpdate), 0)
				}
				pf("    %s %s %s", node1dis, ch.Node1Pub,
					node1time.Format(ISO8601DateTime))
				pf("    %s %s %s", node2dis, ch.Node2Pub,
					node2time.Format(ISO8601DateTime))
			}
		}
		if routeErr != nil {
			pf("Unable to query route to node: %v", routeErr)
		} else {
			pf("Query route to node result: %d routes, %.2f%% success)",
				len(route.Routes), route.SuccessProb*100)
			for i, r := range route.Routes {
				pf("Route %d (%d hops)", i, len(r.Hops))
				for j, hop := range r.Hops {
					sid := lnwire.NewShortChanIDFromInt(hop.ChanId)
					pf("  Hop %d: %s @ %s", j,
						sid, hop.PubKey)
				}
			}
		}
	})

	return nil
}

// canPayServerOps returns true if the local client can pay for server
// operations (push RMs, subscribe, etc) via LN.
func (as *appState) canPayServerOps() bool {
	as.canPayServerMtx.Lock()
	testLifetime := as.canPayServerTestTime.Add(-time.Minute)
	if as.canPayServer && !time.Now().Before(testLifetime) {
		as.canPayServerMtx.Unlock()
		return true
	}
	as.canPayServerMtx.Unlock()

	svrNode := as.c.ServerLNNode()
	if svrNode == "" {
		// Don't know or isn't connected to server
		return false
	}

	// Query route to server to see if it succeeds.
	routeReq := &lnrpc.QueryRoutesRequest{
		PubKey:    svrNode,
		AmtMAtoms: 1000,
		FeeLimit:  client.PaymentFeeLimit(1000),
	}
	_, routeErr := as.lnRPC.QueryRoutes(as.ctx, routeReq)
	if routeErr == nil {
		// Register as able to pay server
		as.canPayServerMtx.Lock()
		as.canPayServer = true
		as.canPayServerTestTime = time.Now()
		as.canPayServerMtx.Unlock()
		return true
	}

	return false
}

// msgInActiveWindow is called to handle a non-command msg in the currently
// active window (pm in private chats, gc msg in gc chats, etc).
func (as *appState) msgInActiveWindow(msg string) {
	if msg == "" {
		return
	}

	as.chatWindowsMtx.Lock()

	as.cmdHistoryIdx = len(as.cmdHistory)
	as.workingCmd = ""

	switch {
	case as.activeCW == activeCWDiag:
		as.chatWindowsMtx.Unlock()
		as.diagMsg(as.styles.err.Render(fmt.Sprintf("Not a command: %q", msg)))
		return

	case as.activeCW == activeCWLog:
		as.chatWindowsMtx.Unlock()
		as.log.Infof(msg)
		return

	case as.activeCW == activeCWLndLog:
		as.chatWindowsMtx.Unlock()
		as.lndLogLines.Write([]byte(msg))
		return

	case as.activeCW < 0 || as.activeCW > len(as.chatWindows):
		// Unknown window.
		as.chatWindowsMtx.Unlock()
		return
	}

	cw := as.chatWindows[as.activeCW]
	as.chatWindowsMtx.Unlock()
	go as.pm(cw, msg)
}

func (as *appState) channelBalance() (dcrutil.Amount, dcrutil.Amount, dcrutil.Amount) {
	as.balMtx.RLock()
	total := as.bal.total
	recv := as.bal.recv
	send := as.bal.send
	as.balMtx.RUnlock()

	return total, recv, send
}

// setupNeedsFlags returns the flags that mark whether the current wallet needs
// to receive funds or open channels for setup.
func (as *appState) setupNeedsFlags() (needsFunds, needsOpenChan bool) {
	as.setupMtx.Lock()
	needsFunds, needsOpenChan = as.setupNeedsFunds, as.setupNeedsSendChan
	as.setupMtx.Unlock()
	return
}

func (as *appState) kxSearchPostAuthor(from clientintf.UserID, pid clientintf.PostID) error {
	err := as.c.KXSearchPostAuthor(from, pid)
	if err != nil {
		as.diagMsg("Unable to start KX search for author of %s: %v", pid,
			err)
	} else {
		as.diagMsg("Starting KX search for author of post %s", pid)
	}
	return err
}

// handleCmd executes the given (already parsed) command line.
func (as *appState) handleCmd(rawText string, args []string) {
	if len(args) == 0 {
		return
	}

	// Store command in the mem cmd history (if it's not repeated).
	storeCmd := (len(as.cmdHistory) == 0 || as.cmdHistory[len(as.cmdHistory)-1] != rawText)
	as.workingCmd = ""
	if storeCmd {
		as.cmdHistory = append(as.cmdHistory, rawText)
	}
	as.cmdHistoryIdx = len(as.cmdHistory)

	renderErr := renderPF(as.styles.err)
	render := renderPF(as.styles.noStyle)

	cmd, subCmd, args := findCommand(args)
	if cmd == nil {
		msg := renderErr("Command %q not found.", args[0]) +
			render(" Type %s%s for help.", string(leader), helpCmd.cmd)
		as.cwHelpMsgs(func(pf printf) {
			pf(msg)
		})
		return
	}

	fullCmd := cmd.cmd
	if subCmd != nil {
		cmd = subCmd
		fullCmd += " " + subCmd.cmd
	}

	// Verify preconditions.
	if !cmd.usableOffline {
		if as.currentConnState() != connStateOnline {
			as.cwHelpMsg("%s%s: cannot issue this command while offline",
				string(leader), fullCmd)
			return
		}
		if !as.canPayServerOps() {
			as.cwHelpMsgs(func(pf printf) {
				pf("%s%s: cannot issue this command without capacity to pay server",
					string(leader), fullCmd)
				pf("Use '/ln svrnode' to check route to server")
				pf("Use '/ln newaddress' to get on-chain funds to the wallet")
				pf("Use '/ln openchannel' to open outbound LN channels")
				pf("Use '/enablecanpay' to skip this test and attempt to send server payments anyway")
			})
			return

		}
	}

	// Call the appropriate handler.
	var err error
	switch {
	case cmd.rawHandler != nil:
		err = cmd.rawHandler(rawText, args, as)
	case cmd.handler != nil:
		err = cmd.handler(args, as)
	default:
		as.cwHelpMsg(renderErr("Command %q unimplemented", fullCmd))
		return
	}

	if errors.Is(err, usageError{}) {
		as.cwHelpMsgs(func(pf printf) {
			pf("")
			pf(renderErr("Incorrect usage of %q: %v", fullCmd, err))
			pf("Usage: %s%s %s", string(leader), fullCmd, cmd.usage)
			pf("Type %s%s %s for additional help", string(leader),
				helpCmd.cmd, fullCmd)
		})
		return
	}
	if err != nil {
		as.log.Errorf("Error executing %q: %v", rawText, err)
		as.cwHelpMsgs(func(pf printf) {
			pf(renderErr("Error executing %q: %v", rawText, err))
		})
	}

	// Save successful command in history file. Ignore errors here as
	// there's nothing to do about it.
	if storeCmd && err == nil && as.cmdHistoryFile != nil {
		_, _ = as.cmdHistoryFile.Write([]byte(rawText))
		_, _ = as.cmdHistoryFile.Write([]byte("\n"))
		_ = as.cmdHistoryFile.Sync()
	}
}

// newAppState initializes the main app state.
func newAppState(sendMsg func(tea.Msg), lndLogLines *sloglinesbuffer.Buffer,
	isRestore bool, args *config) (*appState, error) {

	// firstConn tracks if this is the first connection.
	firstConn := true

	var as *appState
	errMsg := func(msg string) {
		if as != nil {
			as.errorLogMsg(msg)
		}
	}

	// Initialize logging.
	logBknd, err := newLogBackend(sendMsg, errMsg, args.LogFile,
		args.DebugLevel, args.MaxLogFiles)
	if err != nil {
		return nil, err
	}

	// Initialize DB.
	db, err := clientdb.New(clientdb.Config{
		Root:          args.DBRoot,
		MsgsRoot:      args.MsgRoot,
		DownloadsRoot: args.DownloadsRoot,
		Logger:        logBknd.logger("FDDB"),
		ChunkSize:     rpc.MaxChunkSize,
	})
	if err != nil {
		return nil, fmt.Errorf("unable to initialize DB: %v", err)
	}

	ctx := context.Background()

	// Initialize pay client.
	var pc clientintf.PaymentClient = clientintf.FreePaymentClient{}
	var lnRPC lnrpc.LightningClient
	var lnPC *client.DcrlnPaymentClient
	if args.WalletType != "disabled" {
		pcCfg := client.DcrlnPaymentClientCfg{
			TLSCertPath:  args.LNTLSCertPath,
			MacaroonPath: args.LNMacaroonPath,
			Address:      args.LNRPCHost,
			Log:          logBknd.logger("LNPY"),
		}
		lnPC, err = client.NewDcrlndPaymentClient(ctx, pcCfg)
		if err != nil {
			return nil, fmt.Errorf("unable to initialize dcrln pay client: %v", err)
		}
		pc = lnPC
		lnRPC = lnPC.LNRPC()
	}

	var d net.Dialer
	httpDialerFunc := d.DialContext
	var dialer clientintf.Dialer
	if args.ProxyAddr != "" {
		proxy := &socks.Proxy{
			Addr:         args.ProxyAddr,
			Username:     args.ProxyUser,
			Password:     args.ProxyPass,
			TorIsolation: args.TorIsolation,
		}
		httpDialerFunc = proxy.DialContext

		dialCfg := clientintf.ProxyDialerConfig{
			ProxyAddr:    args.ProxyAddr,
			ProxyUser:    args.ProxyUser,
			ProxyPass:    args.ProxyPass,
			TorIsolation: args.TorIsolation,
			ServerAddr:   args.ServerAddr,
			Log:          logBknd.logger("CONN"),
			CircuitLimit: 32,
		}
		dialer = clientintf.NewProxiedDialer(dialCfg)
	} else {
		dialer = clientintf.NetDialer(args.ServerAddr, logBknd.logger("CONN"))
	}

	// Initialize client config.
	cfg := client.Config{
		DB:             db,
		Dialer:         dialer,
		PayClient:      pc,
		Logger:         logBknd.logger,
		LogPings:       args.LogPings,
		ReconnectDelay: 5 * time.Second,
		CompressLevel:  args.CompressLevel,

		CertConfirmer: func(ctx context.Context, cs *tls.ConnectionState,
			svrID *zkidentity.PublicIdentity) error {
			msg := msgConfirmServerCert{
				cs:        cs,
				svrID:     svrID,
				replyChan: make(chan error),
			}

			as.sendMsg(msg)
			var err error
			select {
			case err = <-msg.replyChan:
			case <-ctx.Done():
				err = ctx.Err()
			}
			return err
		},

		LocalIDIniter: func(ctx context.Context) (*zkidentity.FullIdentity, error) {
			// Client needs ID info from user. Request and wait for
			// user response from the UI.
			as.sendMsg(getClientID{})
			select {
			case reply := <-as.clientIDChan:
				return zkidentity.New(reply.nick, reply.name)
			case <-ctx.Done():
				return nil, ctx.Err()
			}
		},

		CheckServerSession: func(connCtx context.Context, lnNode string) (exitErr error) {
			as.connectedMtx.Lock()
			as.connected = connStateCheckingWallet
			as.connectedMtx.Unlock()
			as.sendMsg(connStateCheckingWallet)
			defer func() {
				if exitErr != nil {
					as.connectedMtx.Lock()
					as.connected = connStateOffline
					as.connectedMtx.Unlock()
					as.sendMsg(connStateOffline)
				}
			}()

			wasFirstConn := firstConn
			firstConn = false

			// In case we're restoring from seed, make the client not connect to
			// server by default to allow time for channel restores to happen and
			// any manual intervention in the wallet. This is called in a goroutine
			// because it blocks until the client starts running.
			if isRestore && wasFirstConn {
				go as.c.RemainOffline()
				as.manyDiagMsgsCb(func(pf printf) {
					pf("")
					pf("Wallet was restored - remaining offline from BR server to allow manual interventions")
					pf("Use /online to go online after the LN wallet is verified to be up to date")
					pf("")
					pf("Use /ln restoremultiscb <scb-file> to restore an SCB backup file to force-close old channels")
					pf("")
				})

				// Wait for RemainOffline to close the conn.
				select {
				case <-connCtx.Done():
				case <-ctx.Done():
				}
			}

			select {
			case <-connCtx.Done():
				exitErr = connCtx.Err()
				return
			default:
			}

			as.log.Debugf("Connected to server! Checking LN conn to server node...")
			as.diagMsg("Connected to server! Checking LN conn to server node...")
			backoff := 10 * time.Second
			maxBackoff := 60 * time.Second
			for {
				// Check the basic LN requirements.
				err := client.CheckLNWalletUsable(ctx, lnRPC, lnNode)
				if err == nil {
					// Check for a valid exchange rate.
					eRate := as.exchangeRate()
					if eRate.DCRPrice == 0 {
						err = fmt.Errorf("Exchange rate is zero")
					}
				}

				if err == nil {
					// All good!
					return nil
				}

				as.log.Warnf("LN Wallet not ready for use: %v", err)
				as.manyDiagMsgsCb(func(pf printf) {
					pf("")
					pf("LN Wallet not usable with the "+
						"server: %v", err)
					pf("Checking again in %s", backoff)
					pf("Type /skipwalletcheck to skip these tests")
				})
				select {
				case <-as.skipWalletCheckChan:
					as.log.Warnf("Skipping next wallet check as requested")
					as.diagMsg("Skipping next wallet check as requested")
					return nil
				case <-connCtx.Done():
					exitErr = connCtx.Err()
					return
				case <-ctx.Done():
					exitErr = ctx.Err()
					return
				case <-time.After(backoff):
					backoff = backoff * 2
					if backoff > maxBackoff {
						backoff = maxBackoff
					}
				}
			}
		},

		ServerSessionChanged: func(connected bool, pushRate, subRate, expDays uint64) {
			state := connStateOffline
			if connected {
				state = connStateOnline
			}
			as.connectedMtx.Lock()
			as.connected = state
			showRates := as.pushRate != pushRate || as.subRate != subRate
			showExpDays := as.expirationDays != expDays
			if connected {
				as.pushRate = pushRate
				as.subRate = subRate
				as.expirationDays = expDays
			}
			as.connectedMtx.Unlock()
			as.sendMsg(state)

			if connected {
				if showRates {
					as.diagMsg("Push Rate: %.8f DCR/kB, Sub Rate: %.8f DCR/sub",
						float64(pushRate)/1e8, float64(subRate)/1e11)
				}
				if showExpDays {
					as.diagMsg("Days to Expire Data: %d", expDays)
				}
				as.diagMsg("Client ready!")
			} else {
				as.diagMsg("Connection to server closed")
			}
		},

		PMHandler: func(user *client.RemoteUser, msg rpc.RMPrivateMessage, ts time.Time) {
			fromNick := strescape.Nick(user.PublicIdentity().Nick)
			cw := as.findOrNewChatWindow(user.ID(), fromNick)
			s := as.handleRcvdText(msg.Message, fromNick)
			cw.newRecvdMsg(fromNick, s, ts)
			as.repaintIfActiveWithMention(cw, hasMention(as.c.LocalNick(), s))
		},

		GCInviteHandler: func(user *client.RemoteUser, iid uint64, invite rpc.RMGroupInvite) {
			gcName := strescape.Nick(invite.Name)
			as.gcInvitesMtx.Lock()
			as.gcInvites[gcName] = iid
			as.gcInvitesMtx.Unlock()
			as.diagMsg("Invited to gc \"%s\" (%v) by %q. Type /gc join %s to join.",
				gcName, invite.ID.String(), user.Nick(), gcName)
		},

		GCJoinHandler: func(user *client.RemoteUser, gc clientdb.GCAddressBookEntry) {
			cw := as.findOrNewGCWindow(gc.ID)
			cw.newInternalMsg(fmt.Sprintf("User %q joined GC", user.Nick()))
			as.repaintIfActive(cw)
		},

		GCListUpdated: func(gc clientdb.GCAddressBookEntry) {
			// Remove GC invite if it exists.
			gcName, _ := as.c.GetGCAlias(gc.ID)
			as.gcInvitesMtx.Lock()
			delete(as.gcInvites, gcName)
			as.gcInvitesMtx.Unlock()

			cw := as.findOrNewGCWindow(gc.ID)
			cw.newInternalMsg("GC list updated")
			as.repaintIfActive(cw)
		},

		GCUserParted: func(gcid client.GCID, uid clientintf.UserID, reason string, kicked bool) {
			cw := as.findOrNewGCWindow(gcid)
			if uid == as.c.PublicID() {
				if kicked {
					cw.newInternalMsg(fmt.Sprintf("Admin kicked us! Reason: %q",
						reason))
				} else {
					cw.newInternalMsg(fmt.Sprintf("Parted from GC! Reason: %q",
						reason))
				}
			} else {
				user := uid.String()
				if ru, err := as.c.UserByID(uid); err == nil {
					user = ru.Nick()
				}
				if kicked {
					cw.newInternalMsg(fmt.Sprintf("Admin kicked %q! Reason: %q",
						user, reason))
				} else {
					cw.newInternalMsg(fmt.Sprintf("User %q parted from GC. Reason: %q",
						user, reason))
				}
			}

			as.repaintIfActive(cw)
		},

		GCKilled: func(gcid client.GCID, reason string) {
			cw := as.findOrNewGCWindow(gcid)
			cw.newInternalMsg(fmt.Sprintf("GC killed by admin. Reason: %q", reason))
			as.repaintIfActive(cw)
		},

		GCWithUnkxdMember: func(gcid client.GCID, uid client.UserID) {
			// Alert about missing KX with gc member only once every
			// 24 hours to avoid spamming win0.
			as.missingKXUsersMtx.Lock()
			t := as.missingKXUsers[uid]
			needsWarn := t.Before(time.Now().Add(-24 * time.Hour))
			if needsWarn {
				as.missingKXUsers[uid] = time.Now()
			}
			as.missingKXUsersMtx.Unlock()

			if !needsWarn {
				return
			}

			gc, err := as.c.GetGC(gcid)
			if err != nil {
				as.diagMsg("Unable to find GC %s to warn about"+
					"unkxd user %s: %v", gcid, uid, err)
				return
			}

			gcAdmin, err := as.c.UserByID(gc.Members[0])
			if err != nil {
				as.diagMsg("Unable to find admin %s of GC %s "+
					"to warn about unkxd user %s: %v", gc.Members[0],
					gcid, uid, err)
				return
			}

			alias, _ := as.c.GetGCAlias(gcid)
			if alias == "" {
				alias = gcid.String()
			} else {
				alias = strescape.Nick(alias)
			}
			adminAlias := strescape.Nick(gcAdmin.Nick())
			as.manyDiagMsgsCb(func(pf printf) {
				pf("")
				pf("Messages to user %s in gc %q are "+
					"not being sent due to user not being KXd",
					uid, alias)
				pf("This could happen because the KX process is still " +
					"in progress or because it failed")
				pf("A transitive KX with this user can be attempted " +
					"again by issuing the following command")
				pf("/mi %s %s", adminAlias, uid)
			})
		},

		GCMsgHandler: func(user *client.RemoteUser, msg rpc.RMGroupMessage, ts time.Time) {
			cw := as.findOrNewGCWindow(msg.ID)
			s := as.handleRcvdText(msg.Message, cw.alias)
			cw.newRecvdMsg(user.Nick(), s, ts)
			as.repaintIfActiveWithMention(cw, hasMention(as.c.LocalNick(), s))
		},

		KXCompleted: func(user *client.RemoteUser) {
			as.manyDiagMsgsCb(func(pf printf) {
				pf("Completed KX with user %q ID %s",
					user.Nick(), user.ID())
				pf("Type /msg %s to chat", strescape.Nick(user.Nick()))
			})
		},

		TipReceived: func(user *client.RemoteUser, dcrAmount float64) {
			cw := as.findOrNewChatWindow(user.ID(), strescape.Nick(user.Nick()))
			msg := fmt.Sprintf("Received tip of %.8f DCR", dcrAmount)
			cw.newInternalMsg(msg)
			as.repaintIfActive(cw)
		},

		PostsListReceived: func(user *client.RemoteUser, postList rpc.RMListPostsReply) {
			cw := as.findOrNewChatWindow(user.ID(), strescape.Nick(user.Nick()))
			cw.manyHelpMsgs(func(pf printf) {
				pf("")
				pf("List of user posts (%d total)", len(postList.Posts))
				for _, post := range postList.Posts {
					pf("ID: %s", post.ID)
					pf("Title: %s", strescape.Content(post.Title))
					pf("")
				}
			})
			as.repaintIfActive(cw)
		},

		PostReceived: func(user *client.RemoteUser,
			summ clientdb.PostSummary, pm rpc.PostMetadata) {

			// user == nil when event is a post being relayed for
			// the first time.
			if user != nil {
				if user.IsIgnored() {
					return
				}
			}
			as.diagMsg("Received post %q (%s) from %q",
				summ.Title, summ.ID, user.Nick())

			// Store new post.
			as.loadPosts()

			// Signal updated feed window.
			as.chatWindowsMtx.Lock()
			if as.activeCW != activeCWFeed {
				as.updatedCW[activeCWFeed] = false
			}
			as.chatWindowsMtx.Unlock()

			as.footerInvalidate()
			as.sendMsg(feedUpdated{})
		},

		PostStatusReceived: func(user *client.RemoteUser, pid clientintf.PostID,
			statusFrom clientintf.UserID, status rpc.PostMetadataStatus) {
			as.postsMtx.Lock()

			// If user is nil, post is from myself.
			postFrom := as.c.PublicID()
			if user != nil {
				postFrom = user.ID()
			}

			if user == nil || statusFrom == as.c.PublicID() {
				// Comment from me. Remove comment from list of
				// unsent.
				for i, cmt := range as.myComments {
					if cmt != status.Attributes[rpc.RMPSComment] {
						continue
					}

					copy(as.myComments[i:], as.myComments[i+1:])
					as.myComments = as.myComments[:len(as.myComments)-1]
					break
				}
			}

			// Mark post updated.
			for i := range as.posts {
				post := &as.posts[i]
				if postFrom != post.From || pid != post.ID {
					continue
				}

				// Status is for this post.
				post.LastStatusTS = time.Now()
			}

			if postFrom == as.postSumm.From && pid == as.postSumm.ID {
				// It's the active post, so store the new
				// status update.
				as.postStatus = append(as.postStatus, status)
			}

			as.postsMtx.Unlock()

			if statusFrom != as.c.PublicID() {
				// Signal updated feed window.
				as.chatWindowsMtx.Lock()
				if as.activeCW != activeCWFeed {
					as.updatedCW[activeCWFeed] = false
				}
				as.chatWindowsMtx.Unlock()
				as.footerInvalidate()
			}

			if user != nil && user.IsIgnored() {
				return
			}

			as.sendMsg(status)
		},

		SubscriptionChanged: func(user *client.RemoteUser, subscribed bool) {
			cw := as.findChatWindow(user.ID())
			msg := fmt.Sprintf("%q subscribed to my posts", user.Nick())
			if !subscribed {
				msg = fmt.Sprintf("%q unsubscribed to my posts", user.Nick())
			}
			if cw == nil {
				as.diagMsg(msg)
			} else {
				cw.newInternalMsg(msg)
			}
		},

		ContentListReceived: func(user *client.RemoteUser, files []clientdb.RemoteFile, listErr error) {
			cw := as.findOrNewChatWindow(user.ID(), strescape.Nick(user.Nick()))
			if listErr != nil {
				cw.newInternalMsg(fmt.Sprintf("Unable to list user contents: %v", listErr))
				as.repaintIfActive(cw)
				return
			}

			// Store the list of files so we know what to fetch.
			if len(files) > 0 {
				as.contentMtx.Lock()
				userFiles, ok := as.remoteFiles[cw.uid]
				if !ok {
					userFiles = make(map[clientdb.FileID]clientdb.RemoteFile, len(files))
					as.remoteFiles[cw.uid] = userFiles
				}

				for _, rf := range files {
					userFiles[rf.FID] = rf
				}

				as.contentMtx.Unlock()
			}

			cw.manyHelpMsgs(func(pf printf) {
				pf("")
				pf("Received file list")
				eRate := as.exchangeRate()
				for _, f := range files {
					meta := f.Metadata
					dcrCost := float64(meta.Cost) / 1e8
					usdCost := eRate.DCRPrice * dcrCost

					pf("ID         : %x", meta.MetadataHash())
					pf("Filename   : %q", meta.Filename)
					pf("Description: %q", meta.Description)
					pf("Size       : %d", meta.Size)
					pf("Cost       : %.8f DCR / %0.8f USD", dcrCost, usdCost)
					pf("Hash       : %q", meta.Hash)
					pf("Signature  : %q", meta.Signature)
					pf("")
				}
			})
			as.repaintIfActive(cw)
		},

		FileDownloadCompleted: func(user *client.RemoteUser, fm rpc.FileMetadata, diskPath string) {
			cw := as.findOrNewChatWindow(user.ID(), strescape.Nick(user.Nick()))
			cw.newInternalMsg(fmt.Sprintf("Download completed: %s",
				diskPath))

			fid := clientdb.FileID(fm.MetadataHash())
			as.contentMtx.Lock()
			msg := as.progressMsg[fid]
			if msg != nil {
				delete(as.progressMsg, fid)
				totChunks := len(fm.Manifest)
				msg.msg = fmt.Sprintf("Downloaded %d/%d chunks (100.00%%)- %q",
					totChunks, totChunks, fm.Filename)
			}
			as.contentMtx.Unlock()

			as.repaintIfActive(cw)
		},

		FileDownloadProgress: func(user *client.RemoteUser, fm rpc.FileMetadata,
			nbMissingChunks int) {

			cw := as.findOrNewChatWindow(user.ID(), strescape.Nick(user.Nick()))
			totChunks := len(fm.Manifest)
			gotChunks := totChunks - nbMissingChunks

			fid := clientdb.FileID(fm.MetadataHash())
			as.contentMtx.Lock()
			msg := as.progressMsg[fid]
			if msg == nil {
				msg = cw.newInternalMsg("")
				as.progressMsg[fid] = msg
			}
			msg.msg = fmt.Sprintf("Downloaded %d/%d chunks (%.2f%%) - %q",
				gotChunks, totChunks, float64(gotChunks*100/totChunks),
				fm.Filename)
			as.contentMtx.Unlock()

			as.repaintIfActive(cw)
		},

		TransitiveEvent: func(src, dst client.UserID, event client.TransitiveEvent) {
			srcRU, err := as.c.UserByID(src)
			if err != nil {
				as.diagMsg("Unknown source %s for transitive event %q", event)
				return
			}

			dstRU, _ := as.c.UserByID(dst)
			var msg string
			if dstRU == nil {
				msg = fmt.Sprintf("Received "+
					"transitive %q from %q targeted to unknown user %s",
					event, srcRU.Nick(), dst)
			} else {
				msg = fmt.Sprintf("Received "+
					"transitive %q from %q targeted to user %q",
					event, srcRU.Nick(), dstRU.Nick())
			}
			as.diagMsg(msg)
		},

		UserBlocked: func(ru *client.RemoteUser) {
			cw := as.findOrNewChatWindow(ru.ID(), strescape.Nick(ru.Nick()))
			cw.newInternalMsg("User requested us to block them from further messages")
			as.repaintIfActive(cw)
		},

		KXSearchCompleted: func(ru *client.RemoteUser) {
			as.diagMsg("Completed KX search of %s", ru)
			as.sendMsg(kxSearchCompleted{uid: ru.ID()})
		},

		KXSuggestion: func(user *client.RemoteUser, pii zkidentity.PublicIdentity) {
			target, err := as.c.UserByID(pii.Identity)
			if err == nil {
				// Already KX'd with this user.
				as.diagMsg("%s suggested KXing with already known "+
					"user %s", strescape.Nick(user.Nick()),
					strescape.Nick(target.Nick()))
				return
			}

			as.manyDiagMsgsCb(func(pf printf) {
				mediatorNick := strescape.Nick(user.Nick())
				pf("")
				pf("%s suggested KXing with %s (%q)",
					mediatorNick,
					pii.Identity, strescape.Nick(pii.Nick))
				pf("Type /mi %s %s to request an introduction",
					mediatorNick, pii.Identity)
			})
		},
	}

	var cmdHistoryFile *os.File
	var cmdHistory []string
	if args.CmdHistoryPath != "" {
		if err := os.MkdirAll(filepath.Dir(args.CmdHistoryPath), 0o700); err != nil {
			return nil, err
		}
		flags := os.O_RDWR | os.O_CREATE
		cmdHistoryFile, err = os.OpenFile(args.CmdHistoryPath, flags, 0o600)
		if err != nil {
			return nil, err
		}

		// Read existing commands in history.
		scan := bufio.NewScanner(cmdHistoryFile)
		for scan.Scan() {
			s := strings.TrimSpace(scan.Text())
			if s == "" {
				continue
			}
			cmdHistory = append(cmdHistory, s)
		}
		if scan.Err() != nil {
			return nil, err
		}
	}

	theme, err := newTheme(args)
	if err != nil {
		return nil, err
	}

	// Parse bell command.
	var bellCmd []string
	if args.BellCmd != "" {
		r := regexp.MustCompile(`[^\s"]+|"([^"]*)"`)
		bellCmd = r.FindAllString(args.BellCmd, -1)
		// Remove "".
		for i, s := range bellCmd {
			if len(s) < 2 {
				continue
			}
			if s[0] == '"' && s[len(s)-1] == '"' {
				bellCmd[i] = s[1 : len(s)-1]
			}
		}
	}

	// Initialize client.
	c, err := client.New(cfg)
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithCancel(context.Background())
	as = &appState{
		ctx:         ctx,
		cancel:      cancel,
		c:           c,
		sendMsg:     sendMsg,
		logBknd:     logBknd,
		log:         logBknd.logger("ZTUI"),
		lndLogLines: lndLogLines,
		styles:      theme,
		serverAddr:  args.ServerAddr,
		lnRPC:       lnRPC,
		httpClient: &http.Client{
			Transport: &http.Transport{
				DialContext:           httpDialerFunc,
				ForceAttemptHTTP2:     true,
				MaxIdleConns:          100,
				IdleConnTimeout:       90 * time.Second,
				TLSHandshakeTimeout:   10 * time.Second,
				ExpectContinueTimeout: 1 * time.Second,
			},
		},
		gcInvites: make(map[string]uint64),
		network:   args.Network,
		isRestore: isRestore,

		skipWalletCheckChan: make(chan struct{}),

		minWalletBal: args.MinWalletBal,
		minRecvBal:   args.MinRecvBal,
		minSendBal:   args.MinSendBal,

		cmdHistoryFile: cmdHistoryFile,
		cmdHistory:     cmdHistory,
		cmdHistoryIdx:  len(cmdHistory),

		remoteFiles: make(map[clientintf.UserID]map[clientdb.FileID]clientdb.RemoteFile),
		progressMsg: make(map[clientdb.FileID]*chatMsg),

		activeCW:  activeCWDiag,
		updatedCW: make(map[int]bool),

		clientIDChan:      make(chan getClientIDReply),
		lnOpenChannelChan: make(chan msgLNOpenChannelReply),
		lnRequestRecvChan: make(chan msgLNRequestRecvReply),
		lnFundWalletChan:  make(chan msgLNFundWalletReply),

		winpin:  args.WinPin,
		mimeMap: args.MimeMap,
		bellCmd: bellCmd,

		collator: collate.New(language.Und),

		missingKXUsers: make(map[client.UserID]time.Time),
	}

	as.diagMsg("%s version %s", appName, version.String())

	return as, nil
}
