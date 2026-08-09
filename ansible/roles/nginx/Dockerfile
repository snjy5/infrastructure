FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx/nginx-video.conf /etc/nginx/
COPY nginx/nginx-file.conf /etc/nginx/

EXPOSE 80


