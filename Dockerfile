FROM ruby:2.7.1
WORKDIR /app
COPY Gemfile Gemfile.lock .
RUN bundle config set force_ruby_platform true && bundle install
COPY . .
ENTRYPOINT ["ruby", "notes_cloud_ripper.rb"]
