FROM ruby:2.6

ENV BUNDLER_VERSION 2.0.2
WORKDIR /server

COPY Gemfile Gemfile.lock ./

RUN gem install bundler && \
    bundle config --global frozen 1 && \
    bundle install

COPY app.rb config.ru ./
CMD thin start -p 8000