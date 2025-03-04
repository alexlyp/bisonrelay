package main

import (
	"fmt"
	"sort"
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/companyzero/bisonrelay/client/clientdb"
	"github.com/companyzero/bisonrelay/client/clientintf"
	"github.com/companyzero/bisonrelay/rpc"
)

// feedWindow tracks what needs to be initialized before the app can
// properly start.
type feedWindow struct {
	as    *appState
	posts []clientdb.PostSummary
	idx   int

	viewport viewport.Model
}

func (fw feedWindow) Init() tea.Cmd {
	return nil
}

func (fw *feedWindow) renderPostSumm(post clientdb.PostSummary,
	b *strings.Builder, i int, me clientintf.UserID) {

	pf := fmt.Sprintf
	st := fw.as.styles
	date := post.Date.Format("2006-01-02 15:04")
	lastStatus := "[no status update]"
	if !post.LastStatusTS.IsZero() {
		lastStatus = post.LastStatusTS.Format("2006-01-02 15:04")
	}
	title := post.Title
	if title == "" {
		title = "[Untitled Post]"
	} else {
		title = strings.TrimSpace(title)
	}

	// Determine what to show for "author".
	author, relayedBy := fw.as.postAuthorRelayer(post)
	authorMe := post.AuthorID == me

	if fw.idx == i {
		b.WriteString(st.focused.Render(pf("%s %s by %s", date, title, author)))
	} else {
		b.WriteString(st.timestamp.Render(date))
		b.WriteString(" ")
		b.WriteString(st.msg.Render(title))
		b.WriteString(" ")
		b.WriteString(st.help.Render("by "))
		if authorMe {
			b.WriteString(st.nick.Render(author))
		} else {
			b.WriteString(st.help.Render(author))
		}
	}

	b.WriteString("\n")

	// If this was relayed by someone else, add a "relayed by" line.
	if relayedBy != "" {
		b.WriteString(st.help.Render(pf("    Relayed by %s", relayedBy)))
		b.WriteString("\n")
	}

	b.WriteString(st.help.Render("    Last Update: "))
	b.WriteString(st.timestampHelp.Render(lastStatus))
	b.WriteString("\n\n")
}

func (fw *feedWindow) listPosts() {
	fw.posts = fw.as.allPosts()
	sort.Slice(fw.posts, func(i, j int) bool {
		return fw.posts[i].Date.Sub(fw.posts[j].Date) < 0
	})
	fw.idx = len(fw.posts) - 1
	if fw.idx < 0 {
		fw.idx = 0
	}
}

func (fw *feedWindow) renderPosts() {
	if fw.as.winW > 0 && fw.as.winH > 0 {
		fw.viewport.YPosition = 4
		fw.viewport.Width = fw.as.winW
		fw.viewport.Height = fw.as.winH - 4
	}

	var minOffset, maxOffset int
	b := new(strings.Builder)
	me := fw.as.c.PublicID()
	for i, post := range fw.posts {
		if i == fw.idx {
			minOffset = strings.Count(b.String(), "\n")
		}
		fw.renderPostSumm(post, b, i, me)
		if i == fw.idx {
			maxOffset = strings.Count(b.String(), "\n")
		}
	}

	fw.viewport.SetContent(b.String())

	// Ensure the currently selected index is visible.
	if fw.viewport.YOffset > minOffset {
		// Move viewport up until top of selected item is visible.
		fw.viewport.SetYOffset(minOffset)
	} else if bottom := fw.viewport.YOffset + fw.viewport.Height; bottom < maxOffset {
		// Move viewport down until bottom of selected item is visible.
		fw.viewport.SetYOffset(fw.viewport.YOffset + (maxOffset - bottom))
	}
}

func (fw feedWindow) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	if ss, cmd := maybeShutdown(fw.as, msg); ss != nil {
		return ss, cmd
	}

	switch msg := msg.(type) {
	case tea.WindowSizeMsg: // resize window
		fw.as.winW = msg.Width
		fw.as.winH = msg.Height

	case tea.KeyMsg:
		switch {
		case msg.Type == tea.KeyEsc:
			// Return to main window
			fw.as.markWindowSeen(activeCWFeed)
			fw.as.changeActiveWindowToPrevActive()
			return newMainWindowState(fw.as)

		case msg.Type == tea.KeyUp, msg.String() == "k":
			if fw.idx > 0 {
				fw.idx -= 1
				fw.renderPosts()
			}

		case msg.Type == tea.KeyDown, msg.String() == "j":
			if fw.idx < len(fw.posts)-1 {
				fw.idx += 1
				fw.renderPosts()
			}

		case msg.Type == tea.KeyEnter && fw.idx < len(fw.posts):
			summ := fw.posts[fw.idx]
			fw.as.activatePost(&summ)
			return newPostWin(fw.as, fw.idx, fw.viewport.YOffset)

		case msg.Type == tea.KeyCtrlN:
			// Switch to the window after the feed and go back to
			// main window.
			fw.as.changeActiveWindow(activeCWFeed + 1)
			return newMainWindowState(fw.as)

		// There is no window prior to feed
		// window, so this is is commented out.
		case msg.Type == tea.KeyCtrlP:
			fw.as.changeActiveWindowPrev()
			return newMainWindowState(fw.as)
		}

	case feedUpdated, rpc.PostMetadataStatus:
		fw.listPosts()
		fw.renderPosts()

	case currentTimeChanged:
		fw.as.footerInvalidate()

	default:
		fw.viewport, cmd = fw.viewport.Update(fw)
	}

	return fw, cmd
}

func (fw feedWindow) headerView() string {
	msg := " Posts Feed - Press ESC to return"
	headerMsg := fw.as.styles.header.Render(msg)
	spaces := fw.as.styles.header.Render(strings.Repeat(" ",
		max(0, fw.as.winW-lipgloss.Width(headerMsg))))
	return headerMsg + spaces
}

func (fw feedWindow) footerView() string {
	return fw.as.footerView("")
}

func (fw feedWindow) View() string {
	return fmt.Sprintf("%s\n\n%s\n%s",
		fw.headerView(),
		fw.viewport.View(),
		fw.footerView(),
	)
}

func newFeedWindow(as *appState, feedActiveIdx, yOffsetHint int) (feedWindow, tea.Cmd) {
	as.loadPosts()
	as.markWindowSeen(activeCWFeed)
	fw := feedWindow{as: as}
	fw.listPosts()
	if feedActiveIdx > -1 && feedActiveIdx < len(fw.posts) {
		fw.idx = feedActiveIdx
		fw.viewport.YOffset = yOffsetHint
	}
	fw.renderPosts()
	return fw, nil
}
