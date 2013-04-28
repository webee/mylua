CFLAGS=-O2 -Wall -fPIC

DYN=myreadline.so

OBJS=myreadline.o

$(DYN): $(OBJS)
	$(CC) -shared -o $(DYN) $(OBJS) -lreadline

clean:
	rm -f $(DYN) $(OBJS)
