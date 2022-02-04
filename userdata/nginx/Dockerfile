
FROM nginx

#Copy UI files to the container
ADD js /etc/nginx/html/

# Remove the default nginx.conf
RUN rm -f /etc/nginx/conf.d/default.conf

# Replace with our own nginx.conf
COPY nginx.conf /etc/nginx/conf.d/



