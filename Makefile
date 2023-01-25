# ENV variables for Java tools:
# ROBOT_JAVA_ARGS
# JAVA_OPTS
# JVM_ARGS

ROBOT_ENV=ROBOT_JAVA_ARGS=-Xmx42G
ROBOT=$(ROBOT_ENV) robot
SCALA_ENV=JAVA_OPTS=-Xmx18G
RELATION_GRAPH=$(SCALA_ENV) relation-graph
MATERIALIZER=$(SCALA_ENV) materializer

ONTOLOGY_LIST=ontologies.txt

all: build/relation-graph.ttl

build/mirror.txt: $(ONTOLOGY_LIST)
	mkdir -p $@ && cd $@ &&\
	xargs -n 1 curl --retry 5 -L -O <../../ontologies.txt && cd ../.. &&\
	touch $@

build/ontology.ttl: build/mirror.txt build/referenced-terms.tsv
	$(ROBOT) merge $(addprefix -i build/mirror/,$(shell ls build/mirror)) \
	extract -m BOT -T build/referenced-terms.tsv \
	reason -r ELK -D debug.ofn -o $@

build/referenced-terms.tsv: sparql/referenced_terms.rq
	arq --results=CSV --file=sparql/referenced_terms.rq $(addprefix --data=Repo/,$(shell ls Repo)) >$@

build/ontology-with-data.ttl: build/ontology.ttl
	riot -q --nocheck build/ontology.ttl $(addprefix Repo/,$(shell ls Repo)) >$@

# Using this format is workaround for a java issue in relation-graph: https://stackoverflow.com/questions/43574426/how-to-resolve-java-lang-noclassdeffounderror-javax-xml-bind-jaxbexception
build/ontology-with-data.rdf: build/ontology-with-data.ttl
	riot -q --nocheck --output=rdfxml $< >$@

build/relation-graph.ttl: build/ontology-with-data.rdf
	$(RELATION_GRAPH) --ontology-file $< --output-file $@ --mode RDF --output-subclasses true --reflexive-subclasses true --output-classes true --output-individuals true --disable-owl-nothing true --verbose true

build/abox-inferences.nq: build/ontology.ttl
	$(MATERIALIZER) file --ontology-file build/ontology.ttl --input Repo --output $@ --output-graph-name 'http://example.org/inferred' --suffix-graph false --mark-direct-types true --output-indirect-types true --output-inconsistent true

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
