# ENV variables for Java tools:
# ROBOT_JAVA_ARGS
# JAVA_OPTS
# JVM_ARGS

ROBOT_ENV=ROBOT_JAVA_ARGS=-Xmx42G
ROBOT=$(ROBOT_ENV) robot
SCALA_ENV=JAVA_OPTS=-Xmx18G
RELATION_GRAPH=$(SCALA_ENV) relation-graph
MATERIALIZER=$(SCALA_ENV) materializer
BG_RUNNER=$(SCALA_ENV) blazegraph-runner

ONTOLOGY_LIST=ontologies.txt

all: build/phenokb.jnl

build/mirror.txt: $(ONTOLOGY_LIST)
	mkdir -p build/mirror && cd build/mirror &&\
	xargs -n 1 curl --retry 5 -L -O <../../ontologies.txt && cd ../.. &&\
	touch $@

build/ontology.ttl: build/mirror.txt build/referenced-terms.tsv
	$(ROBOT) merge $(addprefix -i build/mirror/,$(shell ls build/mirror)) \
	extract -m BOT -T build/referenced-terms.tsv \
	reason -r ELK -D debug.ofn -o $@

build/referenced-terms.tsv: sparql/referenced_terms.rq
	arq --results=CSV --file=sparql/referenced_terms.rq $(addprefix --data=Repo/,$(shell ls Repo)) >$@

build/all-data.ttl:
	riot -q --nocheck $(addprefix Repo/,$(shell ls Repo)) >$@

# This is going to be memory-intensive; instead in the future data files shouldn't include Tbox axioms
build/all-data-abox.ttl: build/all-data.ttl
	$(ROBOT) remove -i $< --axioms tbox remove --axioms rbox -o $@

build/ontology-with-data.ttl: build/ontology.ttl build/all-data-abox.ttl
	riot -q --nocheck build/ontology.ttl build/all-data-abox.ttl >$@

# Using this format is workaround for a java issue in relation-graph: https://stackoverflow.com/questions/43574426/how-to-resolve-java-lang-noclassdeffounderror-javax-xml-bind-jaxbexception
build/ontology-with-data.rdf: build/ontology-with-data.ttl
	riot -q --nocheck --output=rdfxml $< >$@

build/relation-graph.ttl: build/ontology-with-data.rdf
	$(RELATION_GRAPH) --ontology-file $< --output-file $@ --mode RDF --output-subclasses true --reflexive-subclasses true --output-classes true --output-individuals true --disable-owl-nothing true --verbose true

build/abox-inferences.nq: build/ontology.ttl
	$(MATERIALIZER) file --ontology-file build/ontology.ttl --input Repo --output $@ --output-graph-name 'http://pheno-repo.phenoscape.org/abox-inferences' --suffix-graph false --mark-direct-types true --output-indirect-types true --output-inconsistent true

build/phenokb.jnl: build/ontology-with-data.ttl build/relation-graph.ttl build/abox-inferences.nq
	$(BG_RUNNER) load --journal=$@ --informat=turtle --graph='http://pheno-repo.phenoscape.org/asserted' build/ontology-with-data.ttl &&\
	$(BG_RUNNER) load --journal=$@ --informat=turtle --graph='http://pheno-repo.phenoscape.org/relation-graph' build/relation-graph.ttl &&\
	$(BG_RUNNER) load --journal=$@ --informat=n-quads --graph='http://pheno-repo.phenoscape.org/abox-inferences' build/abox-inferences.nq

################################################
#### Commands for building the Docker image ####
################################################

VERSION = "1.0"
IM=phenoscape/pheno-repo-tools

docker-build-no-cache:
	@docker build --no-cache -t $(IM):$(VERSION) . \
	&& docker tag $(IM):$(VERSION) $(IM):latest

docker-build:
	@docker build -t $(IM):$(VERSION) . \
	&& docker tag $(IM):$(VERSION) $(IM):latest

docker-build-use-cache-dev:
	@docker build -t $(DEV):$(VERSION) . \
	&& docker tag $(DEV):$(VERSION) $(DEV):latest

docker-clean:
	docker kill $(IM) || echo not running ;
	docker rm $(IM) || echo not made 

docker-publish-no-build:
	@docker push $(IM):$(VERSION) \
	&& docker push $(IM):latest

docker-publish-dev-no-build:
	@docker push $(DEV):$(VERSION) \
	&& docker push $(DEV):latest

docker-publish: docker-build
	@docker push $(IM):$(VERSION) \
	&& docker push $(IM):latest
