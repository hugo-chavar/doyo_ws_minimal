# Dockerfile
FROM elixir:1.18-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base git

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build environment to prod
ENV MIX_ENV=prod

# Copy mix.exs and mix.lock files
COPY mix.exs mix.lock ./

# Fetch dependencies
RUN mix deps.get

# Copy the rest of the application
COPY . .

# Compile the application
RUN mix do compile, release

# Create the final image
FROM alpine:3.22

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs

# Set working directory
WORKDIR /app

# Copy the release from the builder stage
COPY --from=builder /app/_build/prod/rel/doyo_ws ./

# Expose the WebSocket port
EXPOSE 4000

# Set environment variables at runtime
ENV LANG=C.UTF-8 \
    PHOENIX_SERVE_ENDPOINTS=true \
    PORT=4000

# Run the application
CMD ["/app/bin/doyo_ws", "start"]
