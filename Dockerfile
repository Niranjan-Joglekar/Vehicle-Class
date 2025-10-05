# STAGE 1: Build the React Frontend
FROM node:18 AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# STAGE 2: Build the Python Backend & Final Image
FROM python:3.9-slim

# Install system dependencies (nginx, supervisor, and for OpenCV)
RUN apt-get update && apt-get install -y nginx supervisor libgl1 libglib2.0-0 libsm6 libxext6 && apt-get clean

# Set up the main working directory
WORKDIR /app

# Copy and install backend Python dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cpu -r requirements.txt

# Pre-download the EasyOCR models so they are baked into the image
RUN python -c "import easyocr; reader = easyocr.Reader(['en'])"

# Copy your backend source code
COPY backend/ ./backend

# Copy the built frontend from the first stage to the Nginx web root
COPY --from=frontend-builder /app/frontend/build /var/www/html

# Copy your custom Nginx and Supervisor configurations
COPY nginx/nginx.conf /etc/nginx/sites-available/default
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Enable your Nginx configuration
RUN ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Expose the port that Nginx will listen on
EXPOSE 8080

# The main command to start Supervisor, which in turn starts Nginx and Gunicorn
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]