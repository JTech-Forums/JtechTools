import ModPrivateNote from "../../components/mod-private-note";

// Staff-only moderator note, shown above the posts when the moderator
// chose the "top" placement.
<template>
  <ModPrivateNote @topic={{@outletArgs.model}} @place="top" />
</template>
