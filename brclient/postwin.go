package main

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/companyzero/bisonrelay/client"
	"github.com/companyzero/bisonrelay/client/clientdb"
	"github.com/companyzero/bisonrelay/client/clientintf"
	"github.com/companyzero/bisonrelay/internal/strescape"
	"github.com/companyzero/bisonrelay/rpc"
	"github.com/decred/dcrd/dcrutil/v4"
	"github.com/muesli/reflow/wordwrap"
	"github.com/muesli/reflow/wrap"
)

const (
	tempFileTemplate = "brclient-embed-"
)

type comment struct {
	startLine int
	endLine   int
	from      string
	comment   string
	fromUID   *client.UserID
	id        clientintf.ID
	parent    *clientintf.ID
	children  []*comment
	depth     int
	idx       int
	timestamp int64
}

// postWindow tracks what needs to be initialized before the app can
// properly start.
type postWindow struct {
	initless
	as         *appState
	post       rpc.PostMetadata
	comments   []*comment
	myComments []string
	hearts     int
	summ       clientdb.PostSummary
	author     string
	relayedBy  string

	feedActiveIdx   int
	feedYOffsetHint int

	kxSearchingAuthor bool
	kxSearchCompleted bool
	requestedInvites  map[clientintf.UserID]struct{}

	debug string

	startCommentsLine int
	selComment        int
	selEmbed          int
	embeds            []embeddedArgs
	commenting        bool
	replying          bool
	relaying          bool
	cmdErr            string

	viewport viewport.Model
	textArea textAreaModel
}

func (pw *postWindow) processStatus(status rpc.PostMetadataStatus) *comment {
	var uid clientintf.UserID
	var cmt *comment
	if v, ok := status.Attributes[rpc.RMPSHeart]; ok && v != "" {
		if v == rpc.RMPSHeartYes {
			pw.hearts += 1
		} else {
			pw.hearts -= 1
		}
	}
	if v, ok := status.Attributes[rpc.RMPSComment]; ok {
		var fromUID *clientintf.UserID
		var from string
		if err := uid.FromString(status.From); err == nil {
			if uid == pw.as.c.PublicID() {
				from = pw.as.c.LocalNick()
			} else if ru, err := pw.as.c.UserByID(uid); err == nil {
				if ru.IsIgnored() {
					from = "(ignored)"
					v = "(ignored)"
				} else {
					from = ru.PublicIdentity().Nick
				}
			} else if nick, ok := status.Attributes[rpc.RMPFromNick]; ok {
				from = nick
				fromUID = &uid
			} else {
				fromUID = &uid
			}
		} else {
			pw.as.log.Debugf("Not an ID in status.From (%q): %s",
				from, err)
		}

		var parent *clientintf.ID
		if s, ok := status.Attributes[rpc.RMPParent]; ok {
			var id clientintf.ID
			if err := id.FromString(s); err == nil {
				parent = &id
			}
		}

		var timeStamp int64
		if time, ok := status.Attributes[rpc.RMPTimestamp]; ok {
			date, err := strconv.ParseInt(time, 16, 64)
			if err == nil {
				timeStamp = date
			}
		}
		txt := strescape.CannonicalizeNL(strescape.Content(v))
		cmt = &comment{
			from:      from,
			fromUID:   fromUID,
			comment:   txt,
			id:        status.Hash(),
			parent:    parent,
			timestamp: timeStamp,
		}
	}
	return cmt
}

func (pw *postWindow) updatePost() {
	var status []rpc.PostMetadataStatus
	pw.post, pw.summ, status, pw.myComments = pw.as.activePost()

	// Process status updates into hearts and comments.
	if pw.comments != nil {
		pw.comments = pw.comments[:0]
	}
	pw.hearts = 0

	pw.debug = ""

	pw.author, pw.relayedBy = pw.as.postAuthorRelayer(pw.summ)

	_, err := pw.as.c.GetKXSearch(pw.summ.AuthorID)
	if err == nil {
		pw.kxSearchingAuthor = true
	}

	var roots []*comment
	cmap := make(map[clientintf.ID]*comment)
	for i, status := range status {
		cmt := pw.processStatus(status)
		if cmt == nil {
			continue
		}
		cmt.idx = i

		// Create tree of comments.
		cmap[cmt.id] = cmt
		if cmt.parent == nil {
			roots = append(roots, cmt)
			continue
		}

		pc := cmap[*cmt.parent]
		if pc == nil {
			// Comment without knowing parent
			roots = append(roots, cmt)
			continue
		}

		pc.children = append(pc.children, cmt)
		cmt.depth = pc.depth + 1
	}

	// Flatten tree into ordered list of comments.
	stack := make([]*comment, 0, len(roots))
	for i := len(roots) - 1; i >= 0; i-- {
		stack = append(stack, roots[i])
	}
	for len(stack) > 0 {
		l := len(stack)
		el := stack[l-1]
		stack = stack[:l-1]
		pw.comments = append(pw.comments, el)
		for i := len(el.children) - 1; i >= 0; i-- {
			stack = append(stack, el.children[i])
		}
	}
}

func (pw *postWindow) renderComment(cmt *comment, write func(s string), idx int) {
	styles := pw.as.styles

	fromStyle := styles.help
	nickStyle := styles.nick
	contentStyle := styles.noStyle
	uidStyle := styles.help

	const indentSz = 2 // ident per comment level
	totIndent := indentSz * cmt.depth
	indent := strings.Repeat(" ", totIndent)

	if idx == pw.selComment {
		fromStyle = styles.focused
		nickStyle = styles.focused
		contentStyle = styles.focused
		uidStyle = styles.focused
		pw.debug = cmt.id.String()
	}

	write(fromStyle.Render(indent))
	switch {
	case cmt.from == "" && cmt.fromUID == nil:
		write(uidStyle.Render("[unknown from UID]"))
	case cmt.fromUID != nil:
		if ignored, _ := pw.as.c.IsIgnored(*cmt.fromUID); ignored {
			cmt.from = "(ignored)"
			cmt.comment = "(ignored)"
		}

		if cmt.from != "" {
			write(nickStyle.Render(strescape.Nick(cmt.from)))
		} else {
			write(uidStyle.Render("[unknown peer]"))
		}

		if _, ok := pw.requestedInvites[*cmt.fromUID]; ok {
			write(uidStyle.Render("    (requested trans invite from poster)"))
		} else {
			write(uidStyle.Render("    " + cmt.fromUID.String()))
		}
	default:
		write(nickStyle.Render(strescape.Nick(cmt.from)))
	}
	write("\n")
	if cmt.timestamp > 0 {
		date := time.Unix(cmt.timestamp, 0).Format("2006-01-02 15:04")
		write(indent)
		write(styles.help.Render("Received "))
		write(styles.timestampHelp.Render(date))
		write("\n")
	}

	// TODO: Markdown, escape.
	lines := strings.Split(cmt.comment, "\n")
	for _, l := range lines {
		wrappedLine := wordwrap.String(l, pw.as.winW-2-totIndent)
		wlines := strings.Split(wrappedLine, "\n")

		for _, l := range wlines {
			write(indent)
			write(contentStyle.Render(l))
			write("\n")
		}
	}

	write("\n")
}

func (pw *postWindow) renderPost() {
	b := new(strings.Builder)
	var lineCount int
	write := func(s string) {
		lineCount += strings.Count(s, "\n")
		b.WriteString(s)
	}
	pf := fmt.Sprintf

	attr := pw.post.Attributes
	id := attr[rpc.RMPIdentifier]
	styles := pw.as.styles
	date := pw.summ.Date.Format("2006-01-02 15:04")

	write(styles.help.Render(pf("Post %s by ", id)))
	write(styles.nick.Render(pf("%s", pw.author)))
	write("\n")

	if pw.kxSearchCompleted {
		write(styles.help.Render(pf("Completed KX search for author!")))
		write("\n")
	} else if pw.kxSearchingAuthor {
		write(styles.help.Render(pf("KX Searching for author")))
		write("\n")
	}

	if pw.relayedBy != "" {
		write(styles.help.Render(pf("Relayed by %s", pw.relayedBy)))
		write("\n")
	}

	write(styles.help.Render("Received "))
	write(styles.timestampHelp.Render(date))
	//write(styles.help.Render(pf(" - %d ♥", pw.hearts)))
	write("\n\n")

	content := strings.TrimSpace(attr[rpc.RMPMain])
	if content == "" {
		content = " (empty content) "
	}
	content = strescape.Content(content)

	// Replace embedded data tags.
	idx := 0
	embeds := make([]embeddedArgs, 0)
	content = replaceEmbeds(content, func(args embeddedArgs) string {
		// TODO: support showing embedded images/text?
		var s string

		if args.alt != "" {
			s = strescape.Content(args.alt)
			s += " "
		}

		switch {
		case args.download.IsEmpty() && (len(args.data) == 0):
			s += "[Empty link and data]"
		case args.download.IsEmpty() && args.typ == "":
			s += "[Embedded untyped data]"
		case args.download.IsEmpty():
			s += fmt.Sprintf("[Embedded data of type %q]", args.typ)
		default:
			hasFile, err := pw.as.c.HasDownloadedFile(args.download)
			filename := strescape.PathElement(args.filename)
			if filename == "" {
				filename = args.download.ShortLogID()
			}
			if err != nil {
				s += fmt.Sprintf("[Error checking file: %v", err)
			} else if hasFile {
				s += fmt.Sprintf("[File %s]", filename)
			} else {
				eRate := pw.as.exchangeRate()
				dcrCost := dcrutil.Amount(int64(args.cost))
				usdCost := eRate.DCRPrice * dcrCost.ToCoin()
				s += fmt.Sprintf("[Download File %s (size:%s cost:%0.8f DCR / %0.8f USD)]",
					filename,
					hbytes(int64(args.size)),
					dcrCost.ToCoin(), usdCost)
			}
		}

		style := pw.as.styles.embed
		if idx == pw.selEmbed {
			style = pw.as.styles.focused
		}
		idx += 1
		embeds = append(embeds, args)
		return style.Render(s)
	})
	pw.embeds = embeds

	// TODO: render markdown.
	lineLimit := pw.as.winW - 2
	content = wrap.String(wordwrap.String(content, lineLimit), lineLimit)
	write(content)
	write("\n\n")
	write(styles.help.Render("═════ Comments ══════════ (R)eply, (C)omment, (S+I) Req. Invite "))
	write(styles.help.Render(strings.Repeat("═", pw.as.winW-15)))
	write("\n\n")
	pw.startCommentsLine = lineCount

	// Render comments.
	for i, cmt := range pw.comments {
		pw.comments[i].startLine = lineCount
		pw.renderComment(cmt, write, i)
		pw.comments[i].endLine = lineCount
	}

	// Render unsent comments.
	if len(pw.myComments) > 0 {
		write("\n")
		write(styles.help.Render("═════ Unreplicated Comments "))
		write(styles.help.Render(strings.Repeat("═", pw.as.winW-28)))
		write("\n\n")
	}
	commentSep := styles.help.Render(strings.Repeat("┈", pw.as.winW))
	for _, cmt := range pw.myComments {
		write(styles.help.Render(cmt))
		write("\n")
		write(commentSep)
		write("\n")
	}

	pw.viewport.SetContent(b.String())
}

func (pw *postWindow) switchingComment(msg tea.KeyMsg) bool {
	// No comments, so can't be switching comments.
	if pw.selComment >= len(pw.comments) {
		return false
	}

	// Scrolling up from the first comment.
	if pw.selComment == 0 && msg.Type == tea.KeyUp {
		return false
	}

	vstart, vend := pw.viewport.YOffset, pw.viewport.YOffset+pw.viewport.Height-1
	cstart, cend := pw.comments[pw.selComment].startLine, pw.comments[pw.selComment].endLine
	largeComment := cend-cstart >= pw.viewport.Height // comment > than screen height

	// On large comments, we're scrolling the comment itself if the end of
	// comment is not visible in the direction being scrolled.
	if largeComment && msg.Type == tea.KeyUp && cstart < vstart {
		return false
	} else if largeComment && msg.Type == tea.KeyDown && cend > vend {
		return false
	}

	// Going down when the first comment is selected, only switch after the
	// comment is fully visible.
	if pw.selComment == 0 && msg.Type == tea.KeyDown && cend > vend {
		return false
	}

	return pw.viewport.YOffset >
		pw.startCommentsLine-pw.viewport.Height
}

func (pw *postWindow) showSelectedComment() {
	if pw.selComment >= len(pw.comments) {
		return
	}

	vstart, vend := pw.viewport.YOffset, pw.viewport.YOffset+pw.viewport.Height-1
	cstart, cend := pw.comments[pw.selComment].startLine, pw.comments[pw.selComment].endLine
	largeComment := cend-cstart >= pw.viewport.Height // comment > than screen height

	switch {
	case cstart >= vstart && cend <= vend:
		// Entirely visible on screen. No scrolling.

	case !largeComment && cend >= vend:
		// Comment at bottom of screen straddles further than screen
		// height.  Move screen up until comment is fully visible.
		pw.viewport.SetYOffset(vstart + (cend - vend))

	default:
		// Otherwise, move comment to top of screen.
		pw.viewport.SetYOffset(cstart)
	}
}

// selectVisibleComment changes the selected comment index for the one closest
// to the last selected comment.
//
// Note: this is a crappy method to do this. The idea is to figure out comments
// that are visible in the viewport, then switch to the one closest to the
// previously selected comment, whenever _that_ previously selected comment has
// left the viewport.
func (pw *postWindow) selectVisibleComment() {
	if len(pw.comments) == 0 {
		return
	}

	start, end := pw.viewport.YOffset, pw.viewport.YOffset+pw.viewport.Height-1

	// Find comments inside the viewport.
	var visible []int
	var dists []int
	for i := range pw.comments {
		if pw.comments[i].startLine > end {
			break
		}
		if pw.comments[i].endLine <= start+2 {
			continue
		}
		visible = append(visible, i)
		dists = append(dists, abs(i-pw.selComment))
	}

	// Find the visible comment closest to the currently selected one.
	if len(visible) == 0 {
		return
	}
	next := 0
	for i := range visible {
		if dists[i] < dists[next] {
			next = i
		}
	}

	if visible[next] == pw.selComment {
		return
	}
	pw.selComment = visible[next]
	pw.renderPost()
}

// Request trans invite with the currently selected comment sender (if we don't
// know him yet).
func (pw *postWindow) requestTransInvite() {
	if pw.selComment >= len(pw.comments) {
		return
	}

	cmt := pw.comments[pw.selComment]
	if cmt.fromUID == nil {
		// Already have it or don't have an UID.
		return
	}

	if _, ok := pw.requestedInvites[*cmt.fromUID]; ok {
		return
	}

	// Ask post owner to mediate identity.
	fromNick, _ := pw.as.c.UserNick(pw.summ.From)
	cw := pw.as.findOrNewChatWindow(pw.summ.From, fromNick)
	go pw.as.requestMediateID(cw, *cmt.fromUID)

	// Note we've already requested an invite.
	if pw.requestedInvites == nil {
		pw.requestedInvites = make(map[clientintf.UserID]struct{})
	}
	pw.requestedInvites[*cmt.fromUID] = struct{}{}

	pw.renderPost()
}

func (pw *postWindow) kxSearchAuthor() {
	pw.cmdErr = ""
	err := pw.as.kxSearchPostAuthor(pw.summ.From, pw.summ.ID)
	if err != nil {
		pw.cmdErr = err.Error()
	} else {
		pw.kxSearchingAuthor = true
	}
	pw.renderPost()
}

func (pw *postWindow) recalcViewportSize() {
	// First, update the edit line height. This is not entirely accurate
	// because textArea does its own wrapping.
	editHeight := 1
	if pw.commenting || pw.relaying {
		editHeight = pw.textArea.recalcDynHeight(pw.as.winW, pw.as.winH)
	} else {
		pw.textArea.SetHeight(1)
	}

	// Next figure out how much is left for the viewport.
	headerHeight := 1
	footerHeight := 1

	verticalMarginHeight := headerHeight + footerHeight + editHeight
	pw.viewport.YPosition = headerHeight + 1
	pw.viewport.Width = pw.as.winW
	pw.viewport.Height = pw.as.winH - verticalMarginHeight
}

func (pw postWindow) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	var cmds []tea.Cmd

	if ss, cmd := maybeShutdown(pw.as, msg); ss != nil {
		return ss, cmd
	}

	switch msg := msg.(type) {
	case externalViewer:
		if msg.err != nil {
			pw.as.log.Errorf("external viewer failed: %v", msg.err)
		} else {
			pw.as.log.Infof("external viewer successfully closed")
		}

	case tea.WindowSizeMsg: // resize window
		pw.as.winW = msg.Width
		pw.as.winH = msg.Height
		pw.textArea.SetWidth(pw.as.winW)
		pw.recalcViewportSize()
		pw.renderPost()

	case tea.KeyMsg:
		switch {
		case msg.Type == tea.KeyEsc:
			pw.cmdErr = ""
			if pw.commenting {
				pw.commenting = false
				pw.recalcViewportSize()
			} else if pw.relaying {
				pw.relaying = false
				pw.recalcViewportSize()
			} else {
				// Return to feed window
				return newFeedWindow(pw.as, pw.feedActiveIdx,
					pw.feedYOffsetHint)
			}

		case (pw.commenting || pw.relaying) && (msg.Type == tea.KeyUp || msg.Type == tea.KeyDown):
			pw.textArea, cmd = pw.textArea.Update(msg)
			cmds = appendCmd(cmds, cmd)

		case msg.Type == tea.KeyUp, msg.Type == tea.KeyDown:
			// If switching a comment, then select the next/previous
			// comment and scroll to make it visible (instead of
			// scrolling line by line).
			if pw.switchingComment(msg) {
				if msg.Type == tea.KeyDown {
					pw.selComment += 1
				} else {
					pw.selComment -= 1
				}
				pw.selComment = clamp(pw.selComment, 0, len(pw.comments)-1)
				pw.showSelectedComment()
				pw.renderPost()

				return pw, cmd
			}

			// send to viewport
			pw.viewport, cmd = pw.viewport.Update(msg)
			return pw, cmd

		case msg.Type == tea.KeyPgUp, msg.Type == tea.KeyPgDown:
			// Rewrite when alt is pressed to scroll a single line.
			if msg.Type == tea.KeyPgUp && msg.Alt {
				msg.Type = tea.KeyUp
				msg.Alt = false
			} else if msg.Type == tea.KeyPgDown && msg.Alt {
				msg.Type = tea.KeyDown
				msg.Alt = false
			}

			// send to viewport
			pw.viewport, cmd = pw.viewport.Update(msg)

			pw.selectVisibleComment()

			return pw, cmd

		case !pw.commenting && !pw.relaying && (msg.Type == tea.KeyLeft || msg.Type == tea.KeyRight):
			embedCount := len(pw.embeds)
			if msg.Type == tea.KeyLeft {
				pw.selEmbed = clamp(pw.selEmbed-1, 0, embedCount)
			} else {
				pw.selEmbed = clamp(pw.selEmbed+1, 0, embedCount)
			}
			pw.renderPost()

		case msg.Type == tea.KeyCtrlD:
			if len(pw.embeds) > 0 && len(pw.embeds) > pw.selEmbed {
				// TODO - check if already downloaded
				embedded := pw.embeds[pw.selEmbed]
				if embedded.download.IsEmpty() {
					pw.cmdErr = "nothing to download"
					goto done
				}
				hasFile, err := pw.as.c.HasDownloadedFile(embedded.download)
				if err != nil {
					pw.cmdErr = fmt.Sprintf("Failed to check download: %v", err)
					goto done
				}
				if hasFile {
					pw.cmdErr = "Already have file"
					goto done
				}
				uid, err := pw.as.c.UIDByNick(pw.author)
				if err != nil {
					pw.cmdErr = fmt.Sprintf("Unable to find author: %v", err)
					goto done
				}
				// TODO - validate current cost
				err = pw.as.c.GetUserContent(uid, embedded.download)
				if err != nil {
					pw.cmdErr = fmt.Sprintf("Unable to fetch user content: %v", err)
					goto done
				}
			}
		case msg.Type == tea.KeyCtrlV:
			if len(pw.embeds) > 0 && len(pw.embeds) > pw.selEmbed {
				embedded := pw.embeds[pw.selEmbed]
				if len(embedded.data) == 0 {
					pw.cmdErr = "no embedded file"
					goto done
				}
				prog := programByMimeType(pw.as.mimeMap, embedded.typ)
				if prog != "" {
					// TODO: save to downloads/users/file
					f, err := os.CreateTemp("/tmp", tempFileTemplate)
					if err != nil {
						pw.cmdErr = fmt.Sprintf("failed to create temp file: %v", err)
						goto done
					}
					if _, err = f.Write(embedded.data); err != nil {
						pw.cmdErr = fmt.Sprintf("failed to write temp file: %v", err)
						goto done
					}
					f.Close()
					c := exec.Command(prog, f.Name())
					cmd := tea.ExecProcess(c, func(error) tea.Msg {
						os.Remove(f.Name())
						return externalViewer{err: err}
					})
					return pw, cmd
				} else {
					pw.cmdErr = fmt.Sprintf("no external viewer configured for %v", embedded.typ)
				}
			}

		case msg.String() == "alt+\r" && pw.commenting:
			// Alt+enter on new bubbletea version.
			msg.Type = tea.KeyEnter
			fallthrough

		case msg.Alt && msg.Type == tea.KeyEnter && pw.commenting:
			// Add a new line to comment.
			msg.Alt = false
			pw.textArea, cmd = pw.textArea.Update(msg)
			cmds = appendCmd(cmds, cmd)
			pw.recalcViewportSize()

		case msg.Type == tea.KeyEnter && pw.commenting:
			var parent *clientintf.ID
			if pw.replying && pw.selComment < len(pw.comments) {
				selComment := pw.comments[pw.selComment]
				parent = &selComment.id
			}
			text := pw.textArea.Value()
			go pw.as.commentPost(pw.summ.From, pw.summ.ID,
				text, parent)
			pw.textArea.SetValue("")
			pw.recalcViewportSize()
			pw.commenting = false

		case msg.Type == tea.KeyEnter && pw.relaying:
			pw.relaying = false
			text := pw.textArea.Value()

			toUID, err := pw.as.c.UIDByNick(text)
			if err != nil {
				pw.cmdErr = err.Error()
			} else {
				cw := pw.as.findOrNewChatWindow(toUID, text)
				go pw.as.relayPost(pw.summ.From, pw.summ.ID, cw)
			}
			return pw, cmd

		case pw.commenting || pw.relaying:
			oldVal := pw.textArea.Value()
			pw.textArea, cmd = pw.textArea.Update(msg)
			if pw.textArea.Value() != oldVal {
				pw.recalcViewportSize()
			}
			return pw, cmd

		case msg.String() == "c":
			pw.debug = ""
			pw.cmdErr = ""
			pw.commenting = true
			pw.replying = false
			pw.textArea.Placeholder = "Type top-level comment"
			cmd = pw.textArea.Focus()
			pw.textArea.SetWidth(pw.as.winW)
			pw.recalcViewportSize()
			return pw, cmd

		case msg.String() == "r":
			pw.debug = ""
			pw.cmdErr = ""
			pw.commenting = true
			pw.replying = true
			pw.textArea.Placeholder = "Type reply to comment"
			cmd = pw.textArea.Focus()
			pw.textArea.SetWidth(pw.as.winW)
			pw.recalcViewportSize()
			return pw, cmd

		case msg.String() == "I":
			pw.debug = ""
			pw.requestTransInvite()
			return pw, cmd

		case msg.String() == "S":
			pw.debug = ""
			pw.kxSearchAuthor()
			return pw, cmd

		case msg.String() == "R":
			pw.debug = ""
			go pw.as.relayPostToAll(pw.summ.From, pw.summ.ID)
			pw.debug = "Relaying post to subscribers"
			return pw, cmd

		case msg.String() == "U":
			pw.debug = ""
			pw.textArea.SetValue("")
			pw.cmdErr = ""
			pw.relaying = true
			pw.textArea.Placeholder = "Type target nick or id"
			cmd = pw.textArea.Focus()
			return pw, cmd
		}

	case rpc.PostMetadataStatus:
		pw.as.postsMtx.Lock()
		pw.myComments = pw.as.myComments
		pw.as.postsMtx.Unlock()

		pw.updatePost()

		// Force re-render of viewport content. Autoscroll if already
		// at the bottom.
		wasAtBottom := pw.viewport.AtBottom()
		pw.renderPost()
		if wasAtBottom {
			pw.viewport.GotoBottom()
		}

	case sentPostComment:
		pw.as.postsMtx.Lock()
		pw.myComments = pw.as.myComments
		pw.as.postsMtx.Unlock()

		wasAtBottom := pw.viewport.AtBottom()
		pw.renderPost()
		if wasAtBottom {
			pw.viewport.GotoBottom()
		}

	case currentTimeChanged:
		pw.as.footerInvalidate()

	case kxCompleted:
		delete(pw.requestedInvites, msg.uid)

		// See if there are comments by this user and fill the from nick
		// appropriately.
		nick, _ := pw.as.c.UserNick(msg.uid)
		if nick == "" {
			return pw, cmd
		}
		if ignored, _ := pw.as.c.IsIgnored(msg.uid); ignored {
			nick = "(ignored)"
		}
		for _, cmt := range pw.comments {
			if cmt.fromUID == nil || *cmt.fromUID != msg.uid {
				continue
			}

			cmt.fromUID = nil
			cmt.from = nick
		}
		pw.renderPost()

		return pw, cmd

	case kxSearchCompleted:
		if msg.uid == pw.summ.AuthorID {
			pw.kxSearchCompleted = true
			pw.renderPost()
		}
		return pw, cmd

	default:
		// Handle paste, etc
		pw.textArea, cmd = pw.textArea.Update(msg)
		cmds = appendCmd(cmds, cmd)
	}

done:
	return pw, batchCmds(cmds)
}

func (pw postWindow) headerView() string {
	msg := " Post - ESC to return, " +
		"(S+R) Relay Post, (S+S) KX Search Author, (S+U) Relay to User, (Ctrl+D) Download, (Ctrl+V) View File"
	headerMsg := pw.as.styles.header.Render(msg)
	spaces := pw.as.styles.header.Render(strings.Repeat(" ",
		max(0, pw.as.winW-lipgloss.Width(headerMsg))))
	return headerMsg + spaces
}

func (pw postWindow) footerView() string {
	moreLines := ""
	if !pw.viewport.AtBottom() {
		moreLines = pw.as.styles.footer.Render(" (more lines)")
	}

	return pw.as.footerView(moreLines)
}

func (pw postWindow) View() string {
	b := new(strings.Builder)
	write := b.WriteString
	write(pw.headerView())
	write("\n")
	write(pw.viewport.View())
	write("\n")
	write(pw.footerView())
	write("\n")
	if pw.commenting || pw.relaying {
		write(pw.textArea.View())
	} else if pw.cmdErr != "" {
		write(pw.as.styles.err.Render(pw.cmdErr))
	}
	return b.String()
}

func newPostWin(as *appState, feedActiveIdx, feedYOffsetHint int) (postWindow, tea.Cmd) {
	as.loadPosts()
	pw := postWindow{
		as:              as,
		feedActiveIdx:   feedActiveIdx,
		feedYOffsetHint: feedYOffsetHint,
	}
	pw.textArea = newTextAreaModel(as.styles)
	pw.textArea.Placeholder = "Type comment"
	pw.textArea.Prompt = ""
	pw.textArea.SetWidth(as.winW)
	pw.textArea.ShowLineNumbers = false
	pw.textArea.CharLimit = 1024 * 1024
	pw.recalcViewportSize()
	pw.updatePost()
	pw.renderPost()
	pw.viewport.GotoTop()
	return pw, nil
}
