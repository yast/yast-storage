

/*
 *  Author: Arvin Schnell <arvin@suse.de>
 */


#include <scr/Y2AgentComponent.h>
#include <scr/Y2CCAgentComponent.h>
#include <scr/SCRInterpreter.h>

#include "FdiskAgent.h"
#include "LvmAgent.h"
#include "MdAgent.h"


typedef Y2AgentComp <FdiskAgent> Y2FdiskAgentComp;

Y2CCAgentComp <Y2FdiskAgentComp> g_y2ccag_fdisk ("ag_fdisk");

typedef Y2AgentComp <LvmAgent> Y2LvmAgentComp;

Y2CCAgentComp <Y2LvmAgentComp> g_y2ccag_lvm ("ag_lvm");

typedef Y2AgentComp <MdAgent> Y2MdAgentComp;

Y2CCAgentComp <Y2MdAgentComp> g_y2ccag_md ("ag_md");


