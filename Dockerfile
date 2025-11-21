# syntax=docker/dockerfile:1.7
FROM ruby:3.4.6-slim

# Install OS deps: build tools, Node.js/Yarn, MySQL client libs
RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends \
    build-essential \
    nodejs \
    npm \
    git \
    libmariadb-dev-compat \
    libyaml-dev \
    pkg-config \
    curl \
  && npm install -g yarn \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Ruby gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set path /usr/local/bundle \
  && bundle install

# Install JS deps (use npm lockfile)
COPY package.json package-lock.json ./
RUN npm ci

# Copy the rest of the app
COPY . .

ENV RAILS_ENV=development \
    NODE_ENV=development \
    BUNDLE_PATH=/usr/local/bundle

EXPOSE 3000

# Default to bin/dev (foreman) for dev UX
CMD ["bin/dev"]
