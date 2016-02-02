CC=ldmd
CFLAGS=-O -inline -m64

anime_check: anime_check.d
	$(CC) $(CFLAGS) $<

all: anime_check

anime_verif: anime_verif.d
	$(CC) $(CFLAGS) $<

clean:
	rm anime_check anime_verif *.o
