

/*
 *  Author: Arvin Schnell <arvin@suse.de>
 */


#include <scr/Y2AgentComponent.h>
#include <scr/Y2CCAgentComponent.h>
#include <scr/SCRInterpreter.h>

#include "FdiskAgent.h"


typedef Y2AgentComp <FdiskAgent> Y2FdiskAgentComp;

Y2CCAgentComp <Y2FdiskAgentComp> g_y2ccag_fdisk ("ag_fdisk");

