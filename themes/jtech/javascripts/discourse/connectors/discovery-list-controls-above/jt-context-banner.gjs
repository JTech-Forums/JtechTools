import JtContextBanner from "../../components/jt-context-banner";

const JtContextBannerConnector = <template>
  <JtContextBanner
    @category={{@outletArgs.category}}
    @tag={{@outletArgs.tag}}
  />
</template>;

export default JtContextBannerConnector;
