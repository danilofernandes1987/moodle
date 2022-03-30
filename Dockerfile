#cria a imagem de PHP com apache
FROM php:7.4-apache

#executa atualização do container e instalação de alguns softwares
RUN apt-get update \
&& apt upgrade -y \
&& apt-get install -y wget unzip cron nano

#executa a instalação da extensão mysqli para docker
RUN docker-php-ext-install -j$(nproc) mysqli

#executa a instalação da biblioteca libzip-dev
RUN set -eux; apt-get install -y libzip-dev

#executa a instalação de bibliotecas necessárias para correta utilização do moodle
RUN apt-get update \
  && apt-get install -f -y --no-install-recommends \
  rsync \
  netcat \
  libicu-dev \
  libz-dev \
  libpq-dev \
  libjpeg-dev \
  libfreetype6-dev \
  libmcrypt-dev \
  libbz2-dev \
  libjpeg62-turbo-dev \
  gnupg \
  libpng-dev \
  libxslt-dev \
  gettext \
  unixodbc-dev \
  uuid-dev \
  ghostscript \
  libaio1 \
  libgss3 \
  locales \
  sassc \
  libmagickwand-dev \
  libldap2-dev

#executa a instalação de extensões do php necessárias para o Moodle
RUN docker-php-ext-configure soap --enable-soap \
&& docker-php-ext-configure bcmath --enable-bcmath \
&& docker-php-ext-configure pcntl --enable-pcntl \
&& docker-php-ext-configure zip \
&& docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
&& docker-php-ext-install -j$(nproc) zip opcache pgsql intl soap xmlrpc bcmath pcntl sockets ldap

RUN docker-php-ext-configure gd \
    --with-freetype=/usr/include/ \
    --with-jpeg=/usr/include/ \
    --enable-gd

RUN docker-php-ext-install -j$(nproc) gd

RUN pecl install igbinary uuid xmlrpc-beta imagick \
&& docker-php-ext-enable igbinary uuid xmlrpc imagick

RUN apt-get autopurge -y \
    && apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
    && docker-php-source delete

# Configura o arquivo php.ini para melhorar o desempenho do Moodle
RUN set -ex \
    && { \
        echo 'log_errors = on'; \
        echo 'display_errors = off'; \
        echo 'always_populate_raw_post_data = -1'; \
        echo 'cgi.fix_pathinfo = 1'; \
        echo 'session.auto_start = 0'; \
        echo 'upload_max_filesize = 500M'; \
        echo 'post_max_size = 150M'; \
        echo 'max_execution_time = 1800'; \
        echo 'max_input_vars = 5000'; \
        echo '[opcache]'; \
        echo 'opcache.enable = 1'; \
        echo 'opcache.memory_consumption = 128'; \
        echo 'opcache.max_accelerated_files = 8000'; \
        echo 'opcache.revalidate_freq = 60'; \
        echo 'opcache.use_cwd = 1'; \
        echo 'opcache.validate_timestamps = 1'; \
        echo 'opcache.save_comments = 1'; \
        echo 'opcache.enable_file_override = 0'; \
    } | tee /usr/local/etc/php/conf.d/php.ini

WORKDIR /var/www/html


#faz dowload do moodle 3.11, descompacta e configura as permissões
RUN cd /var/www/html \
&& wget https://download.moodle.org/download.php/direct/stable311/moodle-latest-311.tgz \
&& tar -zxvf moodle-latest-311.tgz \
&& rm -R moodle-latest-311.tgz \
&& chmod 0755 /var/www/html -R

#Realiza alteração do proprietário do diretório
RUN chown www-data:www-data /var/www/html -R

#Cria o diretório de arquivos do moodle, concede permissão e altera dono e grupo do diretório
RUN mkdir /var/www/moodledata \
&& chmod 0770 /var/www/moodledata -R \
&& chown www-data:www-data /var/www/moodledata -R

#habilita o CRON
RUN echo "*/1 * * * * root php /var/www/html/moodle/admin/cli/cron.php > /var/log/moodle_cron.log" >> /etc/crontab

RUN touch /var/log/moodle_cron.log

RUN sed -i 's/^exec /service cron start\n\nexec /' /usr/local/bin/apache2-foreground
