package clientdb

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/companyzero/bisonrelay/client/clientintf"
	"github.com/companyzero/bisonrelay/ratchet"
	"github.com/companyzero/bisonrelay/ratchet/disk"
	"github.com/companyzero/bisonrelay/rpc"
	"github.com/companyzero/bisonrelay/zkidentity"
	"golang.org/x/exp/slices"
)

type UserID = clientintf.UserID
type PostID = clientintf.PostID
type RawRVID = clientintf.RawRVID
type SendQID = clientintf.ID
type FileID = clientintf.ID
type ChunkID = clientintf.ID

type ReadTx interface {
	Context() context.Context
}

type ReadWriteTx interface {
	ReadTx
	Writable() bool
}

type KXStage uint8

const (
	KXStageUnknown KXStage = iota
	KXStageStep2IDKX
	KXStageStep3IDKX
)

func (stage KXStage) String() string {
	switch stage {
	case KXStageUnknown:
		return "unknown"
	case KXStageStep2IDKX:
		return "step2idkx"
	case KXStageStep3IDKX:
		return "step3idkx"
	default:
		return fmt.Sprintf("[unknown %d]", stage)
	}
}

// KXData holds information about outstanding KX sessions. In the description
// of the fields, the "source" user is the one that generated the initial
// invite and the "target" user is the one accepting the invite.
type KXData struct {
	// Public is the identity of the remote user. This is empty for the
	// source user and filled with the source user's public id on the
	// target user.
	Public zkidentity.PublicIdentity `json:"public"`

	// InitialRV is the random RV generated by the source user.
	InitialRV RawRVID `json:"initial_rv"`

	// Step3RV is the random RV generated by the target user.
	Step3RV RawRVID `json:"step3_rv"`

	// HalfRatchet is filled by the target user, after accepting the invite
	// but before the source user replied with their half ratchet in
	// Step3RV.
	HalfRatchet *disk.RatchetState `json:"half_ratchet"`

	// MyResetRV is the RV that the local client listens to for reset
	// requests from the remote client.
	MyResetRV RawRVID `json:"my_resetrv"`

	// TheirResetRV is the RV that the remote client listens to for
	// reset requests from the local client.
	TheirResetRV RawRVID `json:"their_resetrv"`

	// Stage is the current stage of the KX process.
	Stage KXStage `json:"stage"`

	// Timestamp is the time when this KX data was stored.
	Timestamp time.Time `json:"timestamp"`

	// Invitee is set in the source user when the the invite was created
	// to be fulfilled by a known target user, usually as a result of
	// a mediated KX.
	Invitee *zkidentity.PublicIdentity `json:"invitee"`

	// IsForReset flags whether this KX request was initiated by a reset
	// request.
	IsForReset bool `json:"is_for_reset"`

	// MediatorID is the identity of a remote user that requested this
	// invite be created (not the source user).
	MediatorID *UserID `json:"mediator_id"`
}

type AddressBookEntry struct {
	ID           *zkidentity.PublicIdentity `json:"id"`
	R            *ratchet.Ratchet           `json:"r"`
	MyResetRV    RawRVID                    `json:"myResetRV"`
	TheirResetRV RawRVID                    `json:"theirResetRV"`
	Ignored      bool                       `json:"ignored"`
}

type GCAddressBookEntry struct {
	ID      zkidentity.ShortID `json:"id"`
	Members []UserID           `json:"members"`
}

func RMGroupListToGCEntry(gc *rpc.RMGroupList, entry *GCAddressBookEntry) {
	entry.ID = gc.ID
	entry.Members = make([]UserID, len(gc.Members))
	copy(entry.Members, gc.Members)
}

type SharedFile struct {
	// FileHash is the hash of the file contents.
	FileHash clientintf.ID `json:"file_hash"`

	// FID is the file id (hash of the metadata, which also includes the
	// content hash).
	FID FileID `json:"fid"`

	// Filename is the base filename of the file.
	Filename string `json:"filename"`
}

// SharedFileAndShares tracks all the shares made for the given shared file.
type SharedFileAndShares struct {
	SF     SharedFile      `json:"shared_file"`
	Cost   uint64          `json:"cost"`
	Size   uint64          `json:"size"`
	Global bool            `json:"global"`
	Shares []clientintf.ID `json:"shares"`
}

type ChunkState string

const (
	ChunkStateHasInvoice     ChunkState = "has_invoice"
	ChunkStatePayingInvoice  ChunkState = "paying_invoice"
	ChunkStateSentInvoice    ChunkState = "sent_invoice"
	ChunkStateRequestedChunk ChunkState = "requested_chunk"
	ChunkStatePaid           ChunkState = "paid"
	ChunkStateUploaded       ChunkState = "uploaded"
	ChunkStateDownloaded     ChunkState = "downloaded"
)

type FileDownload struct {
	UID              UserID             `json:"uid"`
	FID              FileID             `json:"fid"`
	CompletedName    string             `json:"completed_name"`
	Metadata         *rpc.FileMetadata  `json:"metadata"`
	Invoices         map[int]string     `json:"invoices"` // Key is chunk index
	ChunkStates      map[int]ChunkState `json:"chunkstates"`
	ChunkUpdatedTime map[int]time.Time  `json:"chunkupdttimes"`
	IsSentFile       bool               `json:"is_sent_file"`
}

func (fd *FileDownload) GetChunkState(chunkIdx int) ChunkState {
	if fd.ChunkStates == nil {
		return "**nil chunk state map"
	}
	cs, ok := fd.ChunkStates[chunkIdx]
	if !ok {
		return "**chunk idx does not exist"
	}
	return cs
}

func (fd *FileDownload) GetChunkInvoice(chunkIdx int) string {
	if fd.Invoices == nil {
		return "**nil chunk invoices"
	}
	inv, ok := fd.Invoices[chunkIdx]
	if !ok {
		return "**chunk idx does not have invoice"
	}
	return inv
}

// CountChunks returns how many chunks there are at the given chunk state.
func (fd *FileDownload) CountChunks(atState ChunkState) int {
	var res int
	for _, cs := range fd.ChunkStates {
		if cs == atState {
			res += 1
		}
	}
	return res
}

type ChunkUpload struct {
	UID      UserID     `json:"uid"`
	FID      FileID     `json:"fid"`
	CID      ChunkID    `json:"hash"`
	Index    int        `json:"index"`
	Invoices []string   `json:"invoice"`
	Paid     int        `json:"paid"`
	State    ChunkState `json:"state"`
}

type RemoteFile struct {
	FID      FileID           `json:"file_id"`
	UID      UserID           `json:"uid"`
	DiskPath string           `json:"disk_path"`
	Metadata rpc.FileMetadata `json:"metadata"`
}

type PostSummary struct {
	ID           PostID    `json:"id"`
	From         UserID    `json:"from"`
	AuthorID     UserID    `json:"author_id"`
	AuthorNick   string    `json:"author_nick"`
	Date         time.Time `json:"date"`
	LastStatusTS time.Time `json:"last_status_ts"`
	Title        string    `json:"title"`
}

type PostSubscription struct {
	To   UserID    `json:"to"`
	Date time.Time `json:"date"`
}

type SendQueueElement struct {
	ID       clientintf.ID `json:"id"`
	Type     string        `json:"type"`
	Dests    []UserID      `json:"dests"`
	Msg      []byte        `json:"msg"`
	Priority uint          `json:"priority"`
}

// KXSeachQuery holds a specific target used while searching for a KX.
type KXSearchQuery struct {
	User        clientintf.ID   `json:"user"`
	DateSent    time.Time       `json:"date_sent"`
	IDsReceived []clientintf.ID `json:"ids_received"`
}

// KXSearch holds the queries performed when searching for a user.
type KXSearch struct {
	Target  clientintf.ID   `json:"target"`
	Search  rpc.RMKXSearch  `json:"search"`
	Queries []KXSearchQuery `json:"queries"`
}

// MediateIDRequest is used to track in flight mediate identity requests.
type MediateIDRequest struct {
	Mediator UserID    `json:"mediator"`
	Target   UserID    `json:"target"`
	Date     time.Time `json:"date"`
}

type PostKXActionType string

const (
	PKXActionKXSearch  PostKXActionType = "kx_search"
	PKXActionFetchPost PostKXActionType = "fetch_post"
	PKXActionInviteGC  PostKXActionType = "invite_gc"
)

type PostKXAction struct {
	Type      PostKXActionType `json:"type"`
	DateAdded time.Time        `json:"date_added"`
	Data      string           `json:"data"`
}

type PayStatEvent struct {
	Timestamp int64  `json:"ts"`
	Event     string `json:"event"`
	Amount    int64  `json:"amount"`
	PayFee    int64  `json:"pay_fee"`
}

type UserPayStats struct {
	TotalSent     int64 `json:"total_sent"`
	TotalReceived int64 `json:"total_received"`
	TotalPayFee   int64 `json:"total_pay_fee"`
}

type PayStatsSummary struct {
	Prefix string `json:"prefix"`
	Total  int64  `json:"total"`
}

// UnackedRM is an already encrypted but unacked RM.
type UnackedRM struct {
	UID       UserID  `json:"uid"`
	Encrypted []byte  `json:"encrypted"`
	RV        RawRVID `json:"rv"`
	PayEvent  string  `json:"pay_event"`
}

type TipUserAttempt struct {
	UID                  UserID     `json:"uid"`
	Tag                  int32      `json:"tag"`
	MilliAtoms           uint64     `json:"milli_atoms"`
	Created              time.Time  `json:"created"`
	Attempts             int32      `json:"attempts"`
	MaxAttempts          int32      `json:"max_attempts"`
	InvoiceRequested     *time.Time `json:"invoice_requested"`
	PaymentAttempt       *time.Time `json:"payment_attempt"`
	PaymentAttemptCount  uint32     `json:"payment_attempt_count"`
	PaymentAttemptFailed *time.Time `json:"payment_attempt_failed"`
	LastInvoice          string     `json:"last_invoice"`
	PrevInvoices         []string   `json:"prev_invoices"`
	LastInvoiceError     *string    `json:"last_invoice_error,omitempty"`
	Completed            *time.Time `json:"completed,omitempty"`
}

// ResourceRequest is a serialized request for a resource.
type ResourceRequest struct {
	UID        UserID                    `json:"uid"`
	Timestamp  time.Time                 `json:"timestamp"`
	Request    rpc.RMFetchResource       `json:"request"`
	SesssionID clientintf.PagesSessionID `json:"session_id"`
	ParentPage clientintf.PagesSessionID `json:"parent_page"`
}

// FetchedResource is the full information about a fetched resource from a
// remote client.
type FetchedResource struct {
	UID        UserID                    `json:"uid"`
	SessionID  clientintf.PagesSessionID `json:"session_id"`
	ParentPage clientintf.PagesSessionID `json:"parent_page"`
	PageID     clientintf.PagesSessionID `json:"page_id"`
	RequestTS  time.Time                 `json:"request_ts"`
	ResponseTS time.Time                 `json:"response_ts"`
	Request    rpc.RMFetchResource       `json:"request"`
	Response   rpc.RMFetchResourceReply  `json:"response"`
}

// PageSessionOverviewRequest is the overview of a fetch resource request.
type PageSessionOverviewRequest struct {
	UID clientintf.UserID `json:"uid"`
	Tag rpc.ResourceTag   `json:"tag"`
}

// PageSessionOverviewResponse is the overview of a fetch resurce response.
type PageSessionOverviewResponse struct {
	ID     clientintf.PagesSessionID `json:"id"`
	Parent clientintf.PagesSessionID `json:"parent"`
}

// PageSessionOverview stores the overview of a pages session navigation.
type PageSessionOverview struct {
	Requests       []PageSessionOverviewRequest  `json:"requests"`
	Responses      []PageSessionOverviewResponse `json:"responses"`
	LastResponseTS time.Time                     `json:"last_response_ts"`
	LastRequestTS  time.Time                     `json:"last_request_ts"`
}

func (o *PageSessionOverview) append(parent, id clientintf.PagesSessionID) {
	o.Responses = append(o.Responses, PageSessionOverviewResponse{Parent: parent, ID: id})
	o.LastResponseTS = time.Now()
}

func (o *PageSessionOverview) removeRequest(uid clientintf.UserID, tag rpc.ResourceTag) {
	i := slices.IndexFunc(o.Requests, func(v PageSessionOverviewRequest) bool {
		return v.UID == uid && v.Tag == tag
	})
	if i > -1 {
		o.Requests = slices.Delete(o.Requests, i, i+1)
	}
}

func (o *PageSessionOverview) appendRequest(uid clientintf.UserID, tag rpc.ResourceTag) {
	o.Requests = append(o.Requests, PageSessionOverviewRequest{UID: uid, Tag: tag})
	o.LastRequestTS = time.Now()
}

type PMLogEntry struct {
	Message   string `json:"message"`
	From      string `json:"from"`
	Timestamp int64  `json:"timestamp"`
	Internal  bool   `json:"internal"`
}

var (
	LocalIDEmptyError       = errors.New("local ID is not initialized")
	ServerIDEmptyError      = errors.New("server ID is not known")
	ErrNotFound             = errors.New("entry not found")
	ErrAlreadySubscribed    = errors.New("already subscribed")
	ErrNotSubscribed        = errors.New("not subscribed")
	ErrPostStatusValidation = errors.New("invalid post status update")
	ErrAlreadyExists        = errors.New("already exists")
	ErrDuplicatePostStatus  = errors.New("duplicate post status")
)
