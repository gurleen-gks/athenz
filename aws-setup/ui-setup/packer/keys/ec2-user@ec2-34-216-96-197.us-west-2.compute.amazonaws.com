openssl req -newkey rsa:2048 -nodes -keyout service_x509_key -x509 -days 365 -out service_x509_cert
