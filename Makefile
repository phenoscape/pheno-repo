# ENV variables for Java tools:
# ROBOT_JAVA_ARGS
# JAVA_OPTS
# JVM_ARGS

ROBOT_ENV=ROBOT_JAVA_ARGS=-Xmx42G
ROBOT=$(ROBOT_ENV) robot

ONTOLOGY_LIST=ontologies.txt

all: build/relation-graph.ttl

build/mirror: $(ONTOLOGY_LIST)
	mkdir -p $@ && cd $@ &&\
	xargs -n 1 curl --retry 5 -L -O <../../ontologies.txt && cd ../..

build/ontology.ttl: build/mirror
	$(ROBOT) merge $(addprefix -i build/mirror/,$(shell ls build/mirror)) \
	reason -r ELK -D debug.ofn -o $@



build/relation-graph.ttl:
	mkdir -p $@ && cd $@ &&\
	relation-graph --version

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
