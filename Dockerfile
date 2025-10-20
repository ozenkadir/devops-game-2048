# Use a lightweight and stable Nginx base image
FROM nginx:alpine

# Copy static 2048 game files to Nginx's default html directory
COPY webapp /usr/share/nginx/html

# Expose the default HTTP port
EXPOSE 80