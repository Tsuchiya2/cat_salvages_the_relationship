# syntax=docker/dockerfile:1.7
FROM ruby:3.4.6-slim

# Install OS deps: build tools, Node.js/Yarn, MySQL client libs, Playwright dependencies
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
    # Playwright browser dependencies
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
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

# Install Playwright browsers
RUN npx playwright install chromium --with-deps

# Copy the rest of the app
COPY . .

ENV RAILS_ENV=development \
    NODE_ENV=development \
    BUNDLE_PATH=/usr/local/bundle

EXPOSE 3000

# Default to bin/dev (foreman) for dev UX
CMD ["bin/dev"]
