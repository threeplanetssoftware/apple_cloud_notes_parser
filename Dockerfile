FROM ruby:3.3-slim

LABEL org.opencontainers.image.source=https://github.com/threeplanetssoftware/apple_cloud_notes_parser
LABEL org.opencontainers.image.description="This program is a parser for the current version of Apple Notes data syncable with iCloud as seen on Apple handsets in iOS 9 and later."
LABEL org.opencontainers.image.licenses=MIT

WORKDIR /app
COPY Gemfile LICENSE notes_cloud_ripper.rb ./
COPY lib/ /app/lib
RUN apt update && \
	apt-get install -y build-essential pkg-config libsqlite3-dev zlib1g-dev libssl-dev && \
	bundle config set force_ruby_platform true && \
	bundle install && \
	apt-get remove -y build-essential pkg-config && \
	apt autoremove -y 
ENTRYPOINT ["ruby", "notes_cloud_ripper.rb"]
