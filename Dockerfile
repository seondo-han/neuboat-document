FROM asciidoctor/docker-asciidoctor:latest

COPY template/ /template/

RUN gem update --system --no-document --clear-sources --source http://rubygems.org/ && \
    gem install asciidoctor-lists --no-document --clear-sources --source http://rubygems.org/
