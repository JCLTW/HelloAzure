FROM busybox
RUN echo "Hello Azure" \
    && echo $StorageAccountName