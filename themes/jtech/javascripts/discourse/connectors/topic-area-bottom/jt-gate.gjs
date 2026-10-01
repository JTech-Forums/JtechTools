import JtGate from "../../components/jt-gate";

// After the post stream, so the gate sits where the clipped post fades out.
const JtGateConnector = <template>
  <JtGate @topic={{@outletArgs.model}} />
</template>;

export default JtGateConnector;
