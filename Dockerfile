# --- Stage 1: Build ---
FROM elixir:1.19-alpine AS builder

# Install required packages
RUN apk add --no-cache build-base git

# Set working directory
WORKDIR /app

# Install Hex and Rebar (used for dependencies)
RUN mix local.hex --force && \
    mix local.rebar --force

# Set environment to prod
ENV MIX_ENV=prod

# Copy mix files and install deps
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy source code and compile
COPY . .
RUN mix do compile + release

# --- Stage 2: Runtime image ---
FROM alpine:3.22

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs libstdc++ libgcc bash

# Set working directory
WORKDIR /app

# Copy release from builder stage
COPY --from=builder /app/_build/prod/rel/doyo_ws ./

# Expose port
EXPOSE 4000

# Set environment variables
ENV LANG=C.UTF-8 \
    PHOENIX_SERVE_ENDPOINTS=true \
    PORT=4000 \
    MIX_ENV=prod

# Run the application
CMD ["/app/bin/doyo_ws", "start"]
