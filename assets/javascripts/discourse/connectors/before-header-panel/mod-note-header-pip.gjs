import ModNoteHeaderPip from "../../components/mod-note-header-pip";

// Renders the moderator-notes shield pip in the page header — visible to
// staff whenever `currentUser.mod_note_unread_count > 0`, regardless of
// whether the user menu is open. The `before-header-panel-outlet` outlet
// sits inside the header just before the user-menu panel, so the pip lines
// up alongside the existing notification icons.
<template><ModNoteHeaderPip /></template>
