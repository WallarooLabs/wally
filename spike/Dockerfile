FROM scratch
ADD libpthread.so.0 /lib/arm-linux-gnueabihf/libpthread.so.0
ADD libdl.so.2 /lib/arm-linux-gnueabihf/libdl.so.2
ADD libm.so.6 /lib/arm-linux-gnueabihf/libm.so.6
ADD libgcc_s.so.1 /lib/arm-linux-gnueabihf/libgcc_s.so.1
ADD libc.so.6 /lib/arm-linux-gnueabihf/libc.so.6
ADD ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3
ADD librt.so.1 /lib/arm-linux-gnueabihf/librt.so.1
ADD spike /spike
ENTRYPOINT ["/spike"]
