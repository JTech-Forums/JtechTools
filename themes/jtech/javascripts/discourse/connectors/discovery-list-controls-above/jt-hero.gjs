import JtHero from "../../components/jt-hero";

const JtHeroConnector = <template>
  <JtHero @category={{@outletArgs.category}} @tag={{@outletArgs.tag}} />
</template>;

export default JtHeroConnector;
