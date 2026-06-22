# Stage 1: Build Flutter web assets
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app

# Copy dependency files and install
COPY pubspec.* ./
RUN flutter pub get

# Copy source code and build
COPY . .
RUN flutter build web --release

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 8080
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
