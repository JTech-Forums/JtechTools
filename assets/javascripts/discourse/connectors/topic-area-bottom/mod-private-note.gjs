import ModPrivateNote from "../../components/mod-private-note";

// Staff-only moderator note, shown at the bottom of the topic when the
// moderator chose the "bottom" placement (the default).
<template>
  <ModPrivateNote @topic={{@outletArgs.model}} @place="bottom" />
</template>
