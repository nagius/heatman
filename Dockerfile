FROM ruby:2.2
MAINTAINER Joao Rechena "rechena@rechena.com"

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY packages /usr/src/app/
RUN /bin/bash -c "apt-get update && apt-get install -y \$(cat packages) --no-install-recommends && rm -rf /var/lib/apt/lists/*"

COPY Gemfile /usr/src/app/
COPY Gemfile.lock /usr/src/app/
RUN bundle install

COPY . /usr/src/app

EXPOSE 9292

CMD [ "rackup", "-o", "0.0.0.0" ]