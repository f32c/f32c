/*
 * allocation routines.
 */

#include "bas.h"

#define	PAGE_SIZE	4096
#define	PAGE_MASK	(PAGE_SIZE-1)

#define	PAGE_SLOP	0

#define	MEM_PAGE	(PAGE_SIZE - sizeof(struct page_hdr) - PAGE_SLOP)

typedef	union	object	{
	union	object	*next;
	char	value[sizeof(long)];
	long	pading;
} OB;

#define	OBJTOPAGE(op)	(&((PA *)((unsigned long)(op) & ~PAGE_MASK))->ph)

#define	PHTOPAGE(ph)	((ph)->page)

#define	ROUND(x, y)	(((unsigned long)(x) + (y)-1) & ~((y)-1))

typedef	struct	page_hdr {
	struct	page_hdr *next;
	struct	page_hdr *prev;
	struct	page	*page;
	OB	*free;
	int	nfree;
	int	maxfree;
	long	osize;
	size_t	nblks;
} PH;

typedef	struct	page	{
	PH	ph;
	union	{
		char	mem[MEM_PAGE];
		OB	obj[1];
	}u;
}PA;

#define	HASH_SIZ	32

#define	SHASH(x)	(((x)>>4) % HASH_SIZ)

typedef	struct	{
	PH	*page;
	int	hlen;
	int	pfree;
} PAH;

static	PAH	*alloced_pages;
static	PAH	*alloced_pages_HASH_SIZ;
static	PA	*free_pages;
int	pages_alloced;
int	pages_free;
static	int	done_alloc_pages;

/*
 * this variable controls what the likely maximum memory requirement is
 * in pages. If we allocate more than this number of pages, then the
 * allocation scheme will slow down a bit. It is not a hard limit!
 * by default the maxium is ~4Mb which should be enough for most
 * applications.
 */
int	max_mem_size = 1000;

#if PAGE_SLOP != 0
#define	END_PTR(pa, nblks)	((PA *)((char *)(pa) + (nblks) * PAGE_SIZE))
#else
#define	END_PTR(pa, nblks)	((PA *)(pa) + (nblks))
#endif

#define	BLOCK_END(pa) 		END_PTR(pa, pa->ph.nblks)

#define	MAXHASH_FREE		6

static	PH	*alloc_page(size_t, PAH *);
static	PA	*get_space(size_t);
static	PA	*get_pages(size_t, PAH *);
static	void	free_page(PH *);
static	void	free_pap_pages(PAH *);
static	int	do_alloc_pages(void);

#define	MIN_ALLOCSIZ	64

void	*
m_get(register size_t size)
{
	register PH	*php;
	OB	*ob;
	PAH	*pap;

	if(!done_alloc_pages && !do_alloc_pages())
		return( (void *)0);
	/*
	 * round up the size to a number of longs
	 * Assume that MIN_ALLOCSIZ is a multiple of the round up value.
	 */
	if(size < MIN_ALLOCSIZ)
		size = MIN_ALLOCSIZ;
	else
		size = ROUND(size, sizeof(OB) * 4);

	pap = &alloced_pages[SHASH(size)];
	for(php = pap->page ; php ; php = php->next)
		if(php->osize == (int) size && php->nfree > 0)
			break;
	if(php == 0){
		if( (php = alloc_page(size, pap)) == 0)
			return( (void *)0);
	}
	if(php->nfree == php->maxfree)
		pap->pfree -= php->nblks;
	ob = php->free;
	php->free = ob->next;
	--php->nfree;
	return( (void *)ob->value);
}

#ifdef	MDUMP
mdump()
{
	PH	*php;
	PA	*pa;
	PAH	*pap;
	int	i, j;
	int	oc = 0;
	extern	int	printf();

	for(i = 0, pap = alloced_pages ; i < HASH_SIZ ; i++, pap++){
		for(j = 0, php = pap->page ; php ; php = php->next)
			j++;
		printf("bucket %d length %d free len = %d\r\n", i, j, pap->pfree);
		if(j != pap->hlen){
			printf("bad length %d %d\r\n", j, pap->hlen);
		}
		for(j = 0, php = pap->page ; php ; php = php->next, j++){
			printf("\tblock %d = %x page = %x\r\n", j,php, php->page);
		printf("\t\tnfree = %d maxfree = %d osize = %d nblks = %d\r\n",
			php->nfree, php->maxfree, php->osize, php->nblks);
			oc += php->maxfree - php->nfree;
		}
	}
	for(i = 0, pa = free_pages ; pa ; pa = pa->ph.page, i++){
		printf("freeblock %d at %x\r\n", i, pa);
		php = &pa->ph;
		printf("\tnblks = %d tblock_end = %x\r\n",
					php->nblks, BLOCK_END(pa));
	}
	printf("pages_alloced = %d pages_free = %d objs alloced = %d\r\n",
				pages_alloced, pages_free, oc);
}
#endif

void
m_free(void *mem)
{
	register PH	*php;
	register OB	*ob;

	ob = (OB *)mem;
	php = OBJTOPAGE(ob);

#ifdef	CHECK_MFREE
	{ PH	*tphp; PAH *pap; OB *tstob; int n; int i; PA *tpap;

	for(i = 0, pap = alloced_pages ; i < HASH_SIZ ; i++, pap++)
		for(n = 0, tphp = pap->page; tphp ; tphp = tphp->next, n++)
			if(php == tphp)
				goto out;
out:;
	if(tphp == 0 || tphp->nfree >= tphp->maxfree || tphp->nfree < 0 ||
		n > pap->hlen || (n == pap->hlen && tphp->next) ){
		/*
		 * check failed
		 */
		abort();
	}
	tpap = php->page;
	if(php != &tpap->ph)
		abort();
	for(n = 0, tstob = tphp->free ; n < tphp->maxfree && tstob ;
						 n++, tstob = tstob->next)
		if(tstob == ob || OBJTOPAGE(tstob) != tphp ||
				&tpap->u.obj[tstob - tpap->u.obj] != tstob)
			break;
	if(tstob != 0 || n != tphp->nfree){
		/*
		 * already on the free list. Or free list is broken
		 */
		abort();
	}
	}
#endif
	ob->next = php->free;
	php->free = ob;
	php->nfree++;
	if(php->nfree == php->maxfree){
		PAH	*pap = &alloced_pages[SHASH(php->osize)];
		if( (pap->pfree += php->nblks) > MAXHASH_FREE * 3)
			free_pap_pages(pap);
	}
}

void
m_purge()
{
	register PAH	*pap;

	if(!done_alloc_pages)
		return;
	for(pap = alloced_pages ; pap < alloced_pages_HASH_SIZ ; pap++)
		free_pap_pages(pap);
}
		
static	PH *
alloc_page(size_t size, PAH *pap)
{
	register PH	*php;
	register OB	*ob;
	PA	*pa;
	register size_t	nobjs, osize;
	size_t	npages;

	osize = size / sizeof(OB);

	if(size <= MEM_PAGE){
		npages = 1;
		nobjs = (MEM_PAGE/sizeof(OB)) / osize;
	}
	else {
		npages = ((size - MEM_PAGE+PAGE_SIZE-1)/ PAGE_SIZE) + 1;
		nobjs = 1;
	}
	pa = get_pages(npages, pap);

	if(pa == 0)
		return( (PH *)0);

	php = &pa->ph;
	php->page = pa;
	php->osize = size;
	php->nfree = php->maxfree = nobjs;
	php->free = 0;
	for(ob = pa->u.obj ; nobjs; nobjs--, ob += osize){
		ob->next = php->free;
		php->free = ob;
	}
	php->prev = 0;
	if(pap->page)
		pap->page->prev = php;
	php->next = pap->page;
	pap->page = php;
	pap->hlen++;
	pap->pfree += php->nblks;
	return(php);
}

/*
 * Now uses best fit algorithm
 */
static	PA *
get_pages(size_t npages, register PAH *pap)
{
	register PA	*pa, *opa, *npa;
	int	freed = 0;
	int	hasfreed;
	int	maxhash;
	PA	*spa, *sopa = NULL;
	size_t	spages;

/*
	if(pap->pfree > MAXHASH_FREE)
		free_pap_pages(pap);
*/
	for(;;){
		if(pages_free >= (int) npages){
			spa = 0;
			spages = 0;	/* only for lint */
			for(opa = 0, pa = free_pages ; pa ;
						opa = pa, pa = pa->ph.page){
				if(pa->ph.nblks < npages)
					continue;
				if(pa->ph.nblks > npages){
					/*
					 * A potential candidate, see if
					 * it is the best.
					 */
					if(spa == 0 || pa->ph.nblks < spages){
						spages = pa->ph.nblks;
						spa = pa;
						sopa = opa;
					}
					continue;
				}
				pages_free -= npages;
				npa = pa->ph.page;
				if(opa == 0)
					free_pages = npa;
				else
					opa->ph.page = npa;
				return(pa);
			}
			/*
			 * IF spa != 0 then we have found the best fit for
			 * this size
			 */
			if( (pa = spa) != 0){
				pages_free -= npages;
				npa = END_PTR(pa, npages);
				npa->ph.page = pa->ph.page;
				npa->ph.nblks = pa->ph.nblks - npages;
				pa->ph.nblks = npages;
				if(sopa == 0)
					free_pages = npa;
				else {
					assert(sopa != NULL);
					sopa->ph.page = npa;
				}
				return(pa);
			}
		}
		if(!freed){
			hasfreed = 0;
			if(pages_alloced){
				maxhash = max_mem_size / pages_alloced;
				for(pap = alloced_pages ;
					pap < alloced_pages_HASH_SIZ ; pap++)
					if(pap->pfree > maxhash){
						free_pap_pages(pap);
						hasfreed++;
					}
			}
			freed++;
			if(hasfreed)
				continue;
		}
		if(freed == 2)
			return(0);

		if( (pa = get_space(npages)) != 0){
			pa->ph.nblks = npages;
			pages_alloced += npages;
			return(pa);
		}
		hasfreed = 0;
		for(pap = alloced_pages ; pap < alloced_pages_HASH_SIZ ;pap++)
			if(pap->pfree){
				free_pap_pages(pap);
				hasfreed++;
			}
		if(!hasfreed)
			return(0);
		freed++;
	}
}

static	void
free_pap_pages(register PAH *pap)
{
	register PH	*php, *nphp = 0;

	for(php = pap->page ; php ; php = nphp){
		nphp = php->next;
		if(php->nfree == php->maxfree){
			if(php->prev == 0)
				pap->page = nphp;
			else
				php->prev->next = nphp;
			if(nphp != 0)
				nphp->prev = php->prev;
			pap->hlen--;
			pap->pfree -= php->nblks;
			free_page(php);
		}
	}
}

static	void
free_page(php)
PH	*php;
{
	register PA	*pa = php->page;
	register PA	*tpa, *xpa;

	pages_free += php->nblks;

	for(xpa = 0, tpa = free_pages ; tpa && pa > tpa ; tpa = tpa->ph.page)
		xpa = tpa;
	/*
	 * join at top of list
	 */
	if(BLOCK_END(pa) == tpa){
		pa->ph.nblks += tpa->ph.nblks;
		pa->ph.page = tpa->ph.page;
	}
	else
		pa->ph.page = tpa;

	if(xpa == 0)
		free_pages = pa;
	else {
		/*
		 * join at bottom
		 */
		if(BLOCK_END(xpa) == pa){
			xpa->ph.nblks += pa->ph.nblks;
			xpa->ph.page = pa->ph.page;
		}
		else
			xpa->ph.page = pa;
	}
}

extern	void	*sbrk(int);

static	int
do_alloc_pages(void)
{
	register char	*cur_mem;
	register size_t	i;

	done_alloc_pages = 1;

	cur_mem = (char *)sbrk(0);
	i = (char *)ROUND(cur_mem, PAGE_SIZE) - cur_mem;
	if(i < sizeof(PAH) * HASH_SIZ)
		i += PAGE_SIZE;
	if(sbrk(i) == (void *)-1)
		return(0);
	alloced_pages = (PAH *)(void *)cur_mem;
	alloced_pages_HASH_SIZ = alloced_pages + HASH_SIZ;
	i = sizeof(PAH) * HASH_SIZ;
	while(i--)
		*cur_mem++ = 0;
	return(1);
}

static	PA *
get_space(size_t size)
{
	register void	*cur_mem;

	cur_mem = sbrk(PAGE_SIZE * size);
	if(cur_mem == (void *)-1)
		return( (PA *)0);
	if( (int)cur_mem % PAGE_SIZE)
		return( (PA *)0);
	return( (PA *)cur_mem);
}
