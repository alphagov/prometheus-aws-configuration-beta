server {
  listen 9090;
  auth_basic "Prometheus";
  auth_basic_user_file /etc/nginx/conf.d/.htpasswd;

  server_name ~(prom*);

  location / {
    proxy_pass  http://prometheus:9090;
  }

  location /status {
    auth_basic off;
    proxy_pass http://prometheus:9090/status;
  }

  location /health {
    return 200 "Static health check";
  }

  resolver 10.0.0.2 valid=10s;
}

server {
  listen 9090;
  auth_basic "Prometheus";
  auth_basic_user_file /etc/nginx/conf.d/.htpasswd;


  server_name ~(alert*);

  set $alert "${alertmanager_dns_name}";

  location / {
    proxy_pass  http://$alert;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  resolver 10.0.0.2 valid=10s;
}
