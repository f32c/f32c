
#ifndef __CMD_LINK_H_
#define __CMD_LINK_H_

typedef	void	cmdhandler_t(int, char **);

struct cli_cmd_link {
	const char	*name;
	cmdhandler_t	*handler;
};

#define	CMD_LINK(n, h)		 					\
__attribute((__section__("cmd_link"))) 					\
const struct cli_cmd_link n ## __link = {				\
	.name = #n,							\
	.handler = h,							\
}

#endif /* __CMD_LINK_H_ */
