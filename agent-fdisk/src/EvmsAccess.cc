#include <dlfcn.h>
#include <iostream>
#include <sstream>
#include <iterator>
#include <string.h>

#include <ycp/y2log.h>

#include "EvmsAccess.h"
#include "AppUtil.h"

EvmsObject::EvmsObject( object_handle_t obid ) 
    {
    int ret;
    Init();
    id = obid;
    if( (ret = evms_get_info( id, &info_p)!=0 ))
	{
	y2error( "error %d getting info for object:%d", ret, id );
	}
    else
	{
	switch( info_p->type )
	    {
	    case DISK:
		type = EVMS_DISK;
		name = info_p->info.disk.name;
		break;
	    case SEGMENT:
		type = EVMS_SEGMENT;
		name = info_p->info.segment.name;
		break;
	    case REGION:
		type = EVMS_REGION;
		name = info_p->info.region.name;
		break;
	    case CONTAINER:
		type = EVMS_CONTAINER;
		name = info_p->info.container.name;
		break;
	    case VOLUME:
		type = EVMS_VOLUME;
		name = info_p->info.volume.name;
		break;
	    case PLUGIN:
		type = EVMS_PLUGIN;
		name = info_p->info.plugin.short_name;
		break;
	    case EVMS_OBJECT:
		type = EVMS_OBJ;
		name = info_p->info.object.name;
		break;
	    default:
		break;
	    }
	}
    }

EvmsObject::~EvmsObject()
    {
    if( own_ptr && info_p )
	{
	evms_free( info_p );
	}
    info_p = 0;
    }

void EvmsObject::Init()
    {
    id = 0;
    is_data = is_freespace = false;
    size = 0;
    info_p = NULL;
    type = EVMS_UNKNOWN;
    own_ptr = true;
    name.clear();
    }

bool EvmsObject::IsDataType() const
    {
    return( type==EVMS_DISK || type==EVMS_SEGMENT || type==EVMS_REGION ||
            type==EVMS_OBJ );
    }

void EvmsObject::Output( ostream &str ) const
    {
    str << Type();
    if( IsData() )
	{
	str << " D";
	}
    else if( IsFreespace() )
	{
	str << " F";
	}
    str << " id:" << Id() << " name:" << Name();
    }

ostream& operator<<( ostream &str, const EvmsObject& obj )
    {
    obj.Output( str );
    str << endl;
    return( str );
    }

ostream& operator<<( ostream &str, ObjType obj )
    {
    switch( obj )
	{
	case EVMS_DISK:
	    str << "DSK";
	    break;
	case EVMS_SEGMENT:
	    str << "SEG";
	    break;
	case EVMS_REGION:
	    str << "REG";
	    break;
	case EVMS_CONTAINER:
	    str << "CNT";
	    break;
	case EVMS_VOLUME:
	    str << "VOL";
	    break;
	case EVMS_PLUGIN:
	    str << "PLG";
	    break;
	case EVMS_UNKNOWN:
	default:
	    str << "UNK";
	    break;
	}
    return( str );
    }

EvmsDataObject::EvmsDataObject( EvmsObject *const obj ) 
    {
    Init();
    *(EvmsObject*)this = *obj;
    obj->DisownPtr();
    storage_object_info_t* sinfo_p = GetInfop();
    if( sinfo_p )
	{
	size = sinfo_p->size/2;
	if( sinfo_p->data_type==DATA_TYPE )
	    {
	    is_data = true;
	    }
	else if( sinfo_p->data_type==FREE_SPACE_TYPE )
	    {
	    is_freespace = true;
	    }
	}
    else
	{
	y2error( "invalid constructing data object %d", obj->Id() );
	}
    }

EvmsDataObject::EvmsDataObject( object_handle_t id ) : EvmsObject(id)
    {
    EvmsDataObject( (EvmsObject*)this );
    own_ptr = true;
    }

void EvmsDataObject::Init()
    {
    consumed = NULL;
    volume = NULL;
    }

storage_object_info_t* EvmsDataObject::GetInfop()
    {
    storage_object_info_t* sinfo_p = NULL;
    if( info_p )
	{
	switch( Type() )
	    {
	    case EVMS_DISK:
		sinfo_p = &info_p->info.disk;
		break;
	    case EVMS_SEGMENT:
		sinfo_p = &info_p->info.segment;
		break;
	    case EVMS_REGION:
		sinfo_p = &info_p->info.region;
		break;
	    case EVMS_OBJ:
		sinfo_p = &info_p->info.object;
		break;
	    default:
		break;
	    }
	}
    return( sinfo_p );
    }

void EvmsDataObject::AddRelation( EvmsAccess* Acc )
    {
    storage_object_info_t* sinfo_p = GetInfop();
    if( sinfo_p )
	{
	if( sinfo_p->consuming_container>0 )
	    {
	    consumed = Acc->AddObject( sinfo_p->consuming_container );
	    }
	if( sinfo_p->volume>0 )
	    {
	    volume = Acc->AddObject( sinfo_p->volume );
	    }
	}
    }

void EvmsDataObject::Output( ostream& str ) const
    {
    ((EvmsObject*)this)->Output( str );
    str << " size:" << SizeK();
    if( ConsumedBy()!=NULL )
	{
        str << " cons:" << ConsumedBy()->Id();
	}
    if( Volume()!=NULL )
	{
	str << " vol:" << Volume()->Id();
	}
    }

ostream& operator<<( ostream &str, const EvmsDataObject& obj )
    {
    obj.Output( str );
    str << endl;
    return( str );
    }

EvmsContainerObject::EvmsContainerObject( EvmsObject *const obj ) 
    {
    Init();
    *(EvmsObject*)this = *obj;
    obj->DisownPtr();
    storage_container_info_t* cinfo_p = GetInfop();
    if( cinfo_p )
	{
	size = cinfo_p->size/2;
	extended_info_array_t *info_p = NULL;
	int ret = evms_get_extended_info( id, NULL, &info_p );
	if( ret == 0 && info_p != NULL )
	    {
	    for( unsigned i=0; i<info_p->count; i++ )
		{
		if( strcmp( info_p->info[i].name, "PE_Size" )==0 )
		    pe_size = info_p->info[i].value.ui32*512;
		}
	    if( pe_size == 0 )
		{
		y2error( "cannot determine PE size of %d:%s", id, Name().c_str() );
		}
	    evms_free( info_p );
	    }
	else
	    {
	    y2error( "cannot get extended info of %d:%s", id, Name().c_str() );
	    }
	}
    else
	{
	y2error( "invalid constructing container object %d", obj->Id() );
	}
    }

EvmsContainerObject::EvmsContainerObject( object_handle_t id ) : EvmsObject(id)
    {
    EvmsContainerObject( (EvmsObject*)this );
    own_ptr = true;
    }

void EvmsContainerObject::Init()
    {
    creates.clear();
    consumes.clear();
    ctype.clear();
    free = 0;
    pe_size = 0;
    }

storage_container_info_t* EvmsContainerObject::GetInfop()
    {
    storage_container_info_t *sinfo_p = NULL;
    if( info_p && Type()==EVMS_CONTAINER )
	{
	sinfo_p = &info_p->info.container;
	}
    return( sinfo_p );
    }

void EvmsContainerObject::AddRelation( EvmsAccess* Acc )
    {
    storage_container_info_t* sinfo_p = GetInfop();
    if( sinfo_p )
	{
	for( unsigned i=0; i<sinfo_p->objects_consumed->count; i++ )
	    {
	    EvmsObject* obj = 
		Acc->AddObject( sinfo_p->objects_consumed->handle[i] );
	    consumes.push_back( obj );
	    }
	for( unsigned i=0; i<sinfo_p->objects_produced->count; i++ )
	    {
	    EvmsObject* obj = 
		Acc->AddObject( sinfo_p->objects_produced->handle[i] );
	    if( obj->IsData() )
		{
		creates.push_back( obj );
		}
	    else if( obj->IsFreespace() )
		{
		free = free + obj->SizeK();
		}
	    }
	if( sinfo_p->plugin>0 )
	    {
	    EvmsObject *plugin = Acc->AddObject( sinfo_p->plugin );
	    ctype = plugin->Name();
	    }
	}
    }

void EvmsContainerObject::Output( ostream& str ) const
    {
    ((EvmsObject*)this)->Output( str );
    str << " size:" << SizeK() 
        << " free:" << FreeK()
        << " pesize:" << PeSize()
	<< " type:" << TypeName();
    if( consumes.size()>0 )
	{
	str << " consumes:<";
	for( list<EvmsObject *>::const_iterator i=consumes.begin();
	     i!=consumes.end(); i++ )
	    {
	    if( i!=consumes.begin() )
		str << " ";
	    str << (*i)->Id();
	    }
	str << ">";
	}
    if( creates.size()>0 )
	{
	str << " creates:<";
	for( list<EvmsObject *>::const_iterator i=creates.begin();
	     i!=creates.end(); i++ )
	    {
	    if( i!=creates.begin() )
		str << " ";
	    str << (*i)->Id();
	    }
	str << ">";
	}
    }

ostream& operator<<( ostream &str, const EvmsContainerObject& obj )
    {
    obj.Output( str );
    str << endl;
    return( str );
    }

EvmsVolumeObject::EvmsVolumeObject( EvmsObject *const obj ) 
    {
    Init();
    *(EvmsObject*)this = *obj;
    obj->DisownPtr();
    logical_volume_info_s* vinfo_p = GetInfop();
    if( vinfo_p )
	{
	size = vinfo_p->vol_size/2;
	device = name;
	native = !(vinfo_p->flags & VOLFLAG_COMPATIBILITY);
	}
    else
	{
	y2error( "invalid constructing volume object %d", obj->Id() );
	}
    }

EvmsVolumeObject::EvmsVolumeObject( object_handle_t id ) : EvmsObject(id)
    {
    EvmsVolumeObject( (EvmsObject*)this );
    own_ptr = true;
    }

void EvmsVolumeObject::Init()
    {
    device.clear();
    native = false;
    assc = NULL;
    consumed = NULL;
    consumes = NULL;
    }

logical_volume_info_s* EvmsVolumeObject::GetInfop()
    {
    logical_volume_info_s *sinfo_p = NULL;
    if( info_p && Type()==EVMS_VOLUME )
	{
	sinfo_p = &info_p->info.volume;
	}
    return( sinfo_p );
    }

void EvmsVolumeObject::AddRelation( EvmsAccess* Acc )
    {
    logical_volume_info_s* sinfo_p = GetInfop();
    if( sinfo_p )
	{
	if( sinfo_p->object>0 )
	    {
	    consumes = Acc->AddObject( sinfo_p->object );
	    }
	if( sinfo_p->associated_volume>0 )
	    {
	    assc = Acc->AddObject( sinfo_p->associated_volume );
	    }
	}
    }

void EvmsVolumeObject::SetConsumedBy( EvmsObject* Obj )
    {
    if( ConsumedBy()!=NULL )
        {
	y2error( "object %d consumed twice %d and %d", Id(), ConsumedBy()->Id(),
	         Obj->Id() );
        }   
    else
        {
        consumed = Obj;
        }
    }

void EvmsVolumeObject::Output( ostream& str ) const
    {
    ((EvmsObject*)this)->Output( str );
    str << " size:" << SizeK() 
	<< " device:" << Device()
	<< " native:" << Native();
    if( Consumes()!=NULL )
	{
	str << " consumes:" << Consumes()->Id();
	}
    if( ConsumedBy()!=NULL )
	{
	str << " consumed:" << ConsumedBy()->Id();
	}
    if( AssVol()!=NULL )
	{
	str << " assc:" << AssVol()->Id();
	}
    }

ostream& operator<<( ostream &str, const EvmsVolumeObject& obj )
    {
    obj.Output( str );
    str << endl;
    return( str );
    }

int EvmsAccess::PluginFilterFunction( const char* plugin )
    {
    static char *ExcludeList[] = { "/ext2-", "/reiser-", "/jfs-", "/xfs-", 
				   "/swap-" };
    int ret = 0;
    unsigned i = 0;
    while( !ret && i<sizeof(ExcludeList)/sizeof(char*) )
	{
	ret = strstr( plugin, ExcludeList[i] )!=NULL;
	i++;
	}
    y2milestone( "plugin %s ret:%d", plugin, ret );
    return( ret );
    }

EvmsAccess::EvmsAccess()
    {
    y2debug( "begin Konstruktor EvmsAccess" );
    if( !RunningFromSystem() )
	{
	unlink( "/var/lock/evms-engine" );
	}
    evms_set_load_plugin_fct( PluginFilterFunction );
    int ret = evms_open_engine( NULL, (engine_mode_t)ENGINE_READWRITE, NULL, 
                                EVERYTHING, NULL );
    y2debug( "evms_open_engine ret %d", ret );
    if( ret != 0 )
	{
	y2error( "evms_open_engine evms_strerror %s", evms_strerror(ret));
	}
    else
	{
	RereadAllObjects();
	}
    y2debug( "End Konstruktor EvmsAccess" );
    }

void EvmsAccess::RereadAllObjects()
    {
    for( list<EvmsObject*>::iterator p=objects.begin(); p!=objects.end(); p++ )
	{
	delete *p;
	}
    objects.clear();

    handle_array_t* handle_p = 0;
    evms_get_object_list( (object_type_t)0, (data_type_t)0, (plugin_handle_t)0,
                          (object_handle_t)0, (object_search_flags_t)0, 
			  &handle_p );
    for( unsigned i=0; i<handle_p->count; i++ )
	{
	AddObject( handle_p->handle[i] );
	}
    evms_free( handle_p );
    evms_get_plugin_list( EVMS_REGION_MANAGER, (plugin_search_flags_t)0, 
                          &handle_p );
    for( unsigned i=0; i<handle_p->count; i++ )
	{
	AddObject( handle_p->handle[i] );
	}
    evms_free( handle_p );
    AddObjectRelations();
    }

void EvmsAccess::AddObjectRelations()
    {
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin(); 
         Ptr_Ci != objects.end(); Ptr_Ci++ )
	{
	if( (*Ptr_Ci)->IsDataType() )
	    {
	    (*Ptr_Ci)->AddRelation( this );
	    }
	}
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin(); 
         Ptr_Ci != objects.end(); Ptr_Ci++ )
	{
	if( (*Ptr_Ci)->Type()==EVMS_CONTAINER )
	    {
	    (*Ptr_Ci)->AddRelation( this );
	    }
	}
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin(); 
         Ptr_Ci != objects.end(); Ptr_Ci++ )
	{
	if( (*Ptr_Ci)->Type()==EVMS_VOLUME )
	    {
	    (*Ptr_Ci)->AddRelation( this );
	    }
	}
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin(); 
         Ptr_Ci != objects.end(); Ptr_Ci++ )
	{
	if( (*Ptr_Ci)->Type()==EVMS_CONTAINER )
	    {
	    const list<EvmsObject*>& cons 
		= ((EvmsContainerObject*)*Ptr_Ci)->Consumes();
	    for( list<EvmsObject*>::const_iterator i=cons.begin(); 
	         i!=cons.end(); i++ )
		{
		if( (*i)->Type()==EVMS_VOLUME )
		    {
		    ((EvmsVolumeObject*)*i)->SetConsumedBy( *Ptr_Ci );
		    }
		}
	    }
	else if( (*Ptr_Ci)->Type()==EVMS_VOLUME )
	    {
	    EvmsObject* cons = ((EvmsVolumeObject*)*Ptr_Ci)->Consumes();
	    if( cons->Type()==EVMS_VOLUME )
		{
		((EvmsVolumeObject*)cons)->SetConsumedBy( *Ptr_Ci );
		}
	    }
	}
    }

EvmsAccess::~EvmsAccess()
    {
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin(); 
         Ptr_Ci != objects.end(); Ptr_Ci++ )
	 {
	 delete *Ptr_Ci;
	 }
    evms_close_engine();
    }

EvmsObject *const EvmsAccess::AddObject( object_handle_t id )
    {
    EvmsObject * ret;
    if( (ret=Find( id )) == NULL )
	{
	EvmsObject *Obj = new EvmsObject( id );
	ret = Obj;
	y2debug( "id %d type %d", id, Obj->Type() );
	switch( Obj->Type() )
	    {
	    case EVMS_DISK:
	    case EVMS_SEGMENT:
	    case EVMS_REGION:
	    case EVMS_OBJ:
		{
		EvmsDataObject* Data = new EvmsDataObject( Obj );
		objects.push_back( Data );
		delete Obj;
		ret = Data;
		}
		break;
	    case EVMS_CONTAINER:
		{
		EvmsContainerObject* Cont = new EvmsContainerObject( Obj );
		objects.push_back( Cont );
		delete Obj;
		ret = Cont;
		}
		break;
	    case EVMS_VOLUME:
		{
		EvmsVolumeObject* Vol = new EvmsVolumeObject( Obj );
		objects.push_back( Vol );
		delete Obj;
		ret = Vol;
		}
		break;
	    default:
		objects.push_back( Obj );
		break;
	    }
	}
    return( ret );
    }

EvmsObject *const EvmsAccess::Find( object_handle_t id )
    {
    EvmsObject *ret = NULL;
    list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin();
    while( Ptr_Ci != objects.end() && (*Ptr_Ci)->Id()!=id )
	{
	Ptr_Ci++;
	}
    if( Ptr_Ci != objects.end() )
	{
	ret = *Ptr_Ci;
	}
    return( ret );
    }

void EvmsAccess::ListVolumes( list<const EvmsVolumeObject*>& l ) const
    {
    l.clear();
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin();
	 Ptr_Ci != objects.end(); Ptr_Ci++ )
	{
	if( (*Ptr_Ci)->Type() == EVMS_VOLUME )
	    {
	    l.push_back( (EvmsVolumeObject*)*Ptr_Ci );
	    }
	}
    y2milestone( "size %d", l.size() );
    }

void EvmsAccess::ListContainer( list<const EvmsContainerObject*>& l ) const
    {
    l.clear();
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin();
	 Ptr_Ci != objects.end(); Ptr_Ci++ )
	{
	y2debug( "type %d vol %d", (*Ptr_Ci)->Type(), EVMS_CONTAINER );
	if( (*Ptr_Ci)->Type() == EVMS_CONTAINER )
	    {
	    l.push_back( (EvmsContainerObject*)*Ptr_Ci );
	    }
	}
    y2milestone( "size %d", l.size() );
    }

plugin_handle_t EvmsAccess::GetLvmPlugin()
    {
    plugin_handle_t handle = 0;
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin(); 
         Ptr_Ci != objects.end(); Ptr_Ci++ )
	{
	if( (*Ptr_Ci)->Type()==EVMS_PLUGIN && (*Ptr_Ci)->Name()=="LvmRegMgr" )
	    {
	    handle = (*Ptr_Ci)->Id();
	    }
	}
    y2milestone( "handle %d", handle );
    return( handle );
    }

object_handle_t EvmsAccess::FindUsingVolume( object_handle_t id )
    {
    object_handle_t handle = 0;
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin(); 
         Ptr_Ci != objects.end(); Ptr_Ci++ )
	{
	if( (*Ptr_Ci)->Type()==EVMS_VOLUME && 
	    ((EvmsVolumeObject*)*Ptr_Ci)->Consumes()->Id()==id )
	    {
	    handle = (*Ptr_Ci)->Id();
	    }
	}
    y2milestone( "%d used by handle %d", id, handle );
    return( handle );
    }

const EvmsContainerObject* EvmsAccess::FindContainer( const string& name )
    {
    EvmsContainerObject* ret_pi = NULL;
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin(); 
         Ptr_Ci != objects.end(); Ptr_Ci++ )
	{
	if( (*Ptr_Ci)->Type()==EVMS_CONTAINER && (*Ptr_Ci)->Name()==name )
	    {
	    ret_pi = (EvmsContainerObject*)*Ptr_Ci;
	    }
	}
    y2milestone( "Container %s has id %d", name.c_str(), 
                 ret_pi==NULL?0:ret_pi->Id() );
    return( ret_pi );
    }

const EvmsDataObject* EvmsAccess::FindRegion( const string& container, 
					      const string& name )
    {
    EvmsDataObject* ret_pi = NULL;
    string rname = container + "/" + name;
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin(); 
         Ptr_Ci != objects.end(); Ptr_Ci++ )
	{
	if( (*Ptr_Ci)->Type()==EVMS_REGION && (*Ptr_Ci)->Name()==rname )
	    {
	    ret_pi = (EvmsDataObject*)*Ptr_Ci;
	    }
	}
    y2milestone( "Region %s in Container %s has id %d", name.c_str(), 
                 container.c_str(), ret_pi==NULL?0:ret_pi->Id() );
    return( ret_pi );
    }

bool EvmsAccess::CreateCo( const string& Container_Cv, unsigned long PeSize_lv,
                           bool NewMeta_bv, list<string>& Devices_Cv )
    {
    int ret = 0;
    y2milestone( "Container:%s PESize:%lu", Container_Cv.c_str(), PeSize_lv );
    int count = 0;
    Error_C = "";
    CmdLine_C = "CreateCo " + Container_Cv + " PeSize " + dec_string(PeSize_lv);
    CmdLine_C += " <";
    for( list<string>::const_iterator p=Devices_Cv.begin(); p!=Devices_Cv.end();
         p++ )
        {
	if( count>0 )
	    CmdLine_C += ",";
	CmdLine_C += *p;
        y2milestone( "Device %d %s", count++, p->c_str());
        }
    CmdLine_C += ">";
    y2milestone( "CmdLine_C %s", CmdLine_C.c_str());
    string name = Container_Cv;
    if( Container_Cv.find( "lvm/" )!=0 )
	{
	Error_C = "unknown container type" + Container_Cv;
	}
    else
	{
	name.erase( 0, 4 );
	}
    handle_array_t* input = NULL;
    if( Error_C.size()==0 )
	{
	int count = Devices_Cv.size();
	input = (handle_array_t*)malloc( sizeof(handle_array_t)+
	                                 sizeof(object_handle_t)*(count-1) );
	if( input == NULL )
	    {
	    Error_C = "out of memory";
	    }
	else
	    {
	    input->count = count;
	    }
	}
    unsigned i = 0;
    list<string>::const_iterator p=Devices_Cv.begin(); 
    while( Error_C.size()==0 && i<input->count )
	{
	object_type_t ot = (object_type_t)(REGION|SEGMENT);
	int ret = evms_get_object_handle_for_name( ot, (char *)p->c_str(),
						   &input->handle[i] );
	if( ret )
	    {
	    y2milestone( "error: %s", evms_strerror(ret) );
	    Error_C = "could not find object " + *p;
	    }
	y2milestone( "ret %d handle for %s is %d", ret, p->c_str(), 
	             input->handle[i] );
	p++;
	i++;
	}
    i = 0;
    while( Error_C.size()==0 && i<input->count )
	{
	object_handle_t use = FindUsingVolume( input->handle[i] );
	if( use != 0 )
	    {
	    ret = evms_delete(use);
	    y2milestone( "evms_delete %d ret %d", use, ret ); 
	    if( ret )
		{
		Error_C = "could not delete using volume " + dec_string(use);
		y2milestone( "error: %s", evms_strerror(ret) );
		}
	    }
	i++;
	}
    plugin_handle_t lvm = 0;
    if( Error_C.size()==0 )
	{
	lvm = GetLvmPlugin();
	if( lvm == 0 )
	    {
	    Error_C = "could not find lvm plugin";
	    }
	}
    option_array_t* option = NULL;
    if( Error_C.size()==0 )
	{
	int count = 2;
	option = (option_array_t*) malloc( sizeof(option_array_t)+
	                                   (count-1)*sizeof(key_value_pair_t));
	if( option == NULL )
	    {
	    Error_C = "out of memory";
	    }
	else
	    {
	    option->count = count;
	    option->option[0].name = "name";
	    option->option[0].is_number_based = false;
	    option->option[0].type = EVMS_Type_String;
	    option->option[0].flags = 0;
	    option->option[0].value.s = (char*)name.c_str();
	    option->option[1].name = "pe_size";
	    option->option[1].is_number_based = false;
	    option->option[1].type = EVMS_Type_Unsigned_Int32;
	    option->option[1].flags = 0;
	    option->option[1].value.i32 = PeSize_lv/512;
	    }
	}
    object_handle_t output;
    if( Error_C.size()==0 )
	{
	ret = evms_create_container( lvm, input, option, &output );
	if( ret )
	    {
	    y2milestone( "evms_create_container ret %d", ret );
	    y2milestone( "error: %s", evms_strerror(ret) );
	    Error_C = "could not create container " + name;
	    }
	}
    if( Error_C.size()==0 )
	{
	EndEvmsCommand();
	}
    if( Error_C.size()>0 )
	{
	y2milestone( "Error: %s", Error_C.c_str() );
	}
    else
	{
	y2milestone( "OK" );
	}
    if( option )
	free( option );
    if( input )
	free( input );
    return( Error_C.size()==0 );
    }

bool EvmsAccess::CreateLv( const string& LvName_Cv, const string& Container_Cv,
                           unsigned long Size_lv, unsigned long Stripe_lv,
			   unsigned long StripeSize_lv )
    {
    int ret = 0;
    y2milestone( "Name:%s Container:%s Size:%lu Stripe:%lu StripeSize:%lu", 
                 LvName_Cv.c_str(), Container_Cv.c_str(), Size_lv, Stripe_lv,
		 StripeSize_lv );
    Error_C = "";
    CmdLine_C = "CreateLv " + LvName_Cv + " in " + Container_Cv + " Size:" + 
                dec_string(Size_lv) + "k";
    if( Stripe_lv>1 )
	{
	CmdLine_C += " Stripe:" + dec_string(Stripe_lv);
	if( StripeSize_lv>1 )
	    {
	    CmdLine_C += " StripeSize:" + dec_string(StripeSize_lv);
	    }
	}
    y2milestone( "CmdLine_C %s", CmdLine_C.c_str());
    if( Container_Cv.find( "lvm/" )!=0 )
	{
	Error_C = "unknown container type" + Container_Cv;
	}
    handle_array_t reg;
    reg.count = 1;
    reg.handle[0] = 0;
    if( Error_C.size()==0 )
	{
	string name = Container_Cv + "/Freespace";
	int ret = evms_get_object_handle_for_name( REGION, 
	                                           (char *)name.c_str(),
						   &reg.handle[0] );
	if( ret )
	    {
	    Error_C = "could not find object " + name;
	    y2milestone( "ret %s", evms_strerror(ret) );
	    }
	y2milestone( "ret %d handle for %s is %u", ret, name.c_str(),
	             reg.handle[0] );
	}
    plugin_handle_t lvm = 0;
    if( Error_C.size()==0 )
	{
	lvm = GetLvmPlugin();
	if( lvm == 0 )
	    {
	    Error_C = "could not find lvm plugin";
	    }
	}
    option_array_t* option = NULL;
    if( Error_C.size()==0 )
	{
	int count = 2;
	if( Stripe_lv>1 )
	    {
	    count++;
	    if( StripeSize_lv )
		count++;
	    }
	option = (option_array_t*) malloc( sizeof(option_array_t)+
	                                   (count-1)*sizeof(key_value_pair_t));
	if( option == NULL )
	    {
	    Error_C = "out of memory";
	    }
	else
	    {
	    option->count = count;
	    option->option[0].name = "name";
	    option->option[0].is_number_based = false;
	    option->option[0].type = EVMS_Type_String;
	    option->option[0].flags = 0;
	    option->option[0].value.s = (char*)LvName_Cv.c_str();
	    option->option[1].name = "size";
	    option->option[1].is_number_based = false;
	    option->option[1].type = EVMS_Type_Unsigned_Int32;
	    option->option[1].flags = 0;
	    option->option[1].value.i32 = Size_lv*2;
	    if( Stripe_lv>1 )
		{
		option->option[2].name = "stripes";
		option->option[2].is_number_based = false;
		option->option[2].type = EVMS_Type_Unsigned_Int32;
		option->option[2].flags = 0;
		option->option[2].value.i32 = Stripe_lv;
		if( StripeSize_lv )
		    {
		    option->option[3].name = "stripe_size";
		    option->option[3].is_number_based = false;
		    option->option[3].type = EVMS_Type_Unsigned_Int32;
		    option->option[3].flags = 0;
		    option->option[3].value.i32 = StripeSize_lv/512;
		    }
		}
	    }
	}
    handle_array_t* output = NULL;
    if( Error_C.size()==0 )
	{
	ret = evms_create( lvm, &reg, option, &output );
	if( ret )
	    {
	    y2milestone( "evms_create ret %d", ret );
	    y2milestone( "ret %s", evms_strerror(ret) );
	    Error_C = "could not create region " + LvName_Cv;
	    }
	else
	    {
	    ret = evms_create_compatibility_volume( output->handle[0] );
	    if( ret )
		{
		y2milestone( "evms_create_compatibility_volume ret %d", ret );
		y2milestone( "ret %s", evms_strerror(ret) );
		Error_C = "could not create compatibility volume " + LvName_Cv;
		}
	    }
	evms_free( output );
	}
    if( Error_C.size()==0 )
	{
	EndEvmsCommand();
	}
    if( Error_C.size()>0 )
	{
	y2milestone( "Error: %s", Error_C.c_str() );
	}
    else
	{
	y2milestone( "OK" );
	}
    return( Error_C.size()==0 );
    }

bool EvmsAccess::DeleteLv( const string& LvName_Cv, const string& Container_Cv )
    {
    int ret = 0;
    y2milestone( "Name:%s Container:%s", LvName_Cv.c_str(), 
                 Container_Cv.c_str() );
    Error_C = "";
    CmdLine_C = "RemoveLv " + LvName_Cv + " in " + Container_Cv;
    y2milestone( "CmdLine_C %s", CmdLine_C.c_str());
    if( Container_Cv.find( "lvm/" )!=0 )
	{
	Error_C = "unknown container type" + Container_Cv;
	}
    handle_array_t reg;
    reg.count = 1;
    reg.handle[0] = 0;
    if( Error_C.size()==0 )
	{
	string name = Container_Cv + "/" + LvName_Cv;
	int ret = evms_get_object_handle_for_name( REGION, 
	                                           (char *)name.c_str(),
						   &reg.handle[0] );
	if( ret )
	    {
	    Error_C = "could not find object " + name;
	    y2milestone( "ret %s", evms_strerror(ret) );
	    }
	y2milestone( "ret %d handle for %s is %u", ret, name.c_str(),
	             reg.handle[0] );
	}
    if( Error_C.size()==0 )
	{
	object_handle_t use = FindUsingVolume( reg.handle[0] );
	if( use != 0 )
	    {
	    ret = evms_delete(use);
	    y2milestone( "evms_delete %d ret %d", use, ret ); 
	    if( ret )
		{
		Error_C = "could not delete using volume " + dec_string(use);
		y2milestone( "error: %s", evms_strerror(ret) );
		}
	    }
	if( Error_C.size()==0 )
	    {
	    ret = evms_delete( reg.handle[0] );
	    if( ret )
		{
		y2milestone( "evms_delete ret %d", ret );
		y2milestone( "ret %s", evms_strerror(ret) );
		Error_C = "could not delete region " + LvName_Cv;
		}
	    }
	}
    if( Error_C.size()==0 )
	{
	EndEvmsCommand();
	}
    if( Error_C.size()>0 )
	{
	y2milestone( "Error: %s", Error_C.c_str() );
	}
    else
	{
	y2milestone( "OK" );
	}
    return( Error_C.size()==0 );
    }

bool EvmsAccess::ExtendCo( const string& Container_Cv, const string& PvName_Cv )
    {
    int ret = 0;
    y2milestone( "Container:%s PvName:%s", Container_Cv.c_str(), 
                 PvName_Cv.c_str() );
    Error_C = "";
    CmdLine_C = "ExtendCo " + Container_Cv + " by " + PvName_Cv;
    y2milestone( "CmdLine_C %s", CmdLine_C.c_str());
    if( Container_Cv.find( "lvm/" )!=0 )
	{
	Error_C = "unknown container type" + Container_Cv;
	}
    object_handle_t region = 0;
    if( Error_C.size()==0 )
	{
	object_type_t ot = (object_type_t)(REGION|SEGMENT);
	int ret = evms_get_object_handle_for_name( ot, 
	                                           (char *)PvName_Cv.c_str(),
						   &region );
	if( ret )
	    {
	    y2milestone( "error: %s", evms_strerror(ret) );
	    Error_C = "could not find object " + PvName_Cv;
	    }
	y2milestone( "ret %d handle for %s is %d", ret, PvName_Cv.c_str(), 
	             region );
	}
    if( Error_C.size()==0 )
	{
	object_handle_t use = FindUsingVolume( region );
	if( use != 0 )
	    {
	    ret = evms_delete(use);
	    y2milestone( "evms_delete %d ret %d", use, ret ); 
	    if( ret )
		{
		Error_C = "could not delete using volume " + dec_string(use);
		y2milestone( "error: %s", evms_strerror(ret) );
		}
	    }
	}
    const EvmsContainerObject* Co_p = NULL;
    if( Error_C.size()==0 )
	{
	Co_p = FindContainer( Container_Cv );
	if( Co_p == NULL )
	    {
	    Error_C = "could not find container " + Container_Cv;
	    }
	}
    plugin_handle_t lvm = 0;
    if( Error_C.size()==0 )
	{
	lvm = GetLvmPlugin();
	if( lvm == 0 )
	    {
	    Error_C = "could not find lvm plugin";
	    }
	}
    if( Error_C.size()==0 && Co_p )
	{
	ret = evms_transfer( region, lvm, Co_p->Id(), NULL );
	if( ret )
	    {
	    Error_C = "could not transfer " + PvName_Cv + " to container " + 
	              Container_Cv;
	    y2milestone( "ret %s", evms_strerror(ret) );
	    }
	}
    if( Error_C.size()==0 )
	{
	EndEvmsCommand();
	}
    if( Error_C.size()>0 )
	{
	y2milestone( "Error: %s", Error_C.c_str() );
	}
    else
	{
	y2milestone( "OK" );
	}
    return( Error_C.size()==0 );
    }

bool EvmsAccess::ShrinkCo( const string& Container_Cv, const string& PvName_Cv )
    {
    int ret = 0;
    y2milestone( "Container:%s PvName:%s", Container_Cv.c_str(), 
                 PvName_Cv.c_str() );
    Error_C = "";
    CmdLine_C = "ShrinkCo " + Container_Cv + " by " + PvName_Cv;
    y2milestone( "CmdLine_C %s", CmdLine_C.c_str());
    if( Container_Cv.find( "lvm/" )!=0 )
	{
	Error_C = "unknown container type" + Container_Cv;
	}
    object_handle_t region = 0;
    if( Error_C.size()==0 )
	{
	object_type_t ot = (object_type_t)(REGION|SEGMENT);
	int ret = evms_get_object_handle_for_name( ot, 
	                                           (char *)PvName_Cv.c_str(),
						   &region );
	if( ret )
	    {
	    y2milestone( "error: %s", evms_strerror(ret) );
	    Error_C = "could not find object " + PvName_Cv;
	    }
	y2milestone( "ret %d handle for %s is %d", ret, PvName_Cv.c_str(), 
	             region );
	}
    if( Error_C.size()==0 )
	{
	if( evms_can_remove_from_container( region ) )
	    {
	    Error_C = "could not remove " + PvName_Cv + "  from container " + 
	              Container_Cv;
	    }
	}
    const EvmsContainerObject* Co_p = NULL;
    if( Error_C.size()==0 )
	{
	Co_p = FindContainer( Container_Cv );
	if( Co_p == NULL )
	    {
	    Error_C = "could not find container " + Container_Cv;
	    }
	}
    plugin_handle_t lvm = 0;
    if( Error_C.size()==0 )
	{
	lvm = GetLvmPlugin();
	if( lvm == 0 )
	    {
	    Error_C = "could not find lvm plugin";
	    }
	}
    if( Error_C.size()==0 && Co_p )
	{
	ret = evms_transfer( region, 0, 0, NULL );
	if( ret )
	    {
	    Error_C = "could not transfer " + PvName_Cv + " out of container " +
	              Container_Cv;
	    y2milestone( "ret %s", evms_strerror(ret) );
	    }
	else
	    {
	    ret = evms_create_compatibility_volume( region );
	    if( ret )
		{
		y2milestone( "evms_create_compatibility_volume ret %d", 
			     ret );
		y2milestone( "ret %s", evms_strerror(ret) );
		Error_C = "could not create compatibility volume " + 
			  PvName_Cv;
		}
	    }
	}
    if( Error_C.size()==0 )
	{
	EndEvmsCommand();
	}
    if( Error_C.size()>0 )
	{
	y2milestone( "Error: %s", Error_C.c_str() );
	}
    else
	{
	y2milestone( "OK" );
	}
    return( Error_C.size()==0 );
    }

bool EvmsAccess::DeleteCo( const string& Container_Cv )
    {
    int ret = 0;
    y2milestone( "Container:%s", Container_Cv.c_str() );
    Error_C = "";
    CmdLine_C = "DeleteCo " + Container_Cv;
    y2milestone( "CmdLine_C %s", CmdLine_C.c_str());
    if( Container_Cv.find( "lvm/" )!=0 )
	{
	Error_C = "unknown container type" + Container_Cv;
	}
    const EvmsContainerObject* Co_p = NULL;
    if( Error_C.size()==0 )
	{
	Co_p = FindContainer( Container_Cv );
	if( Co_p == NULL )
	    {
	    Error_C = "could not find container " + Container_Cv;
	    }
	else
	    {
	    y2milestone( "handle for %s is %u", 
	                 Container_Cv.c_str(), Co_p->Id() );
	    for( list<EvmsObject *>::const_iterator p=Co_p->Consumes().begin(); 
	         p!=Co_p->Consumes().end(); p++ )
		{
		y2milestone( "consumes %d", (*p)->Id() );
		}
	    }
	}
    if( Error_C.size()==0 )
	{
	ret = evms_delete( Co_p->Id() );
	if( ret )
	    {
	    y2milestone( "evms_delete ret %d", ret );
	    y2milestone( "ret %s", evms_strerror(ret) );
	    Error_C = "could not delete container " + Container_Cv;
	    }
	else
	    {
	    for( list<EvmsObject *>::const_iterator p=Co_p->Consumes().begin(); 
	         p!=Co_p->Consumes().end(); p++ )
		{
		ret = evms_create_compatibility_volume( (*p)->Id() );
		if( ret )
		    {
		    y2milestone( "evms_create_compatibility_volume ret %d", 
		                 ret );
		    y2milestone( "ret %s", evms_strerror(ret) );
		    Error_C = "could not create compatibility volume " + 
		              (*p)->Name();
		    }
		}
	    }
	}
    if( Error_C.size()==0 )
	{
	EndEvmsCommand();
	}
    if( Error_C.size()>0 )
	{
	y2milestone( "Error: %s", Error_C.c_str() );
	}
    else
	{
	y2milestone( "OK" );
	}
    return( Error_C.size()==0 );
    }

bool EvmsAccess::ChangeLvSize( const string& Name_Cv, 
                               const string& Container_Cv,
			       unsigned long Size_lv )
    {
    int ret = 0;
    y2milestone( "LvName:%s Container:%s NewSize:%lu", Name_Cv.c_str(),
                 Container_Cv.c_str(), Size_lv );
    Error_C = "";
    CmdLine_C = "ChangeLvSize of " + Name_Cv + " in " + Container_Cv +
                " to " + dec_string(Size_lv) + "k";
    y2milestone( "CmdLine_C %s", CmdLine_C.c_str());
    if( Container_Cv.find( "lvm/" )!=0 )
	{
	Error_C = "unknown container type" + Container_Cv;
	}
    const EvmsDataObject* Rg_p = NULL;
    if( Error_C.size()==0 )
	{
	Rg_p = FindRegion( Container_Cv, Name_Cv );
	if( Rg_p == NULL )
	    {
	    Error_C = "could not find volume " + Name_Cv + " in " + Container_Cv;
	    }
	else
	    {
	    y2milestone( "handle for %s in %s is %u", Name_Cv.c_str(),
	                 Container_Cv.c_str(), Rg_p->Id() );
	    }
	}
    if( Error_C.size()==0 )
	{
	y2milestone( "old size:%llu new size:%lu", Rg_p->SizeK(), Size_lv );
	option_array_t option;
	option.count = 1;
	/*
	if( Size_lv != Rg_p->SizeK() && Rg_p->Volume()!=NULL )
	    {
	    ret = evms_delete( Rg_p->Volume()->Id() );
	    if( ret )
		{
		y2milestone( "evms_delete ret %d", ret );
		y2milestone( "ret %s", evms_strerror(ret) );
		Error_C = "could not delete volume " + Container_Cv;
		}
	    }
	*/
	if( Size_lv > Rg_p->SizeK() )
	    {
	    option.option[0].name = "add_size";
	    option.option[0].is_number_based = false;
	    option.option[0].type = EVMS_Type_Unsigned_Int32;
	    option.option[0].flags = 0;
	    option.option[0].value.i32 = (Size_lv-Rg_p->SizeK())*2;
	    ret = evms_expand( Rg_p->Id(), NULL, &option );
	    if( ret )
		{
		y2milestone( "evms_expand ret %d", ret );
		y2milestone( "ret %s", evms_strerror(ret) );
		Error_C = "could not expand volume " + Name_Cv + " to " +
		          dec_string(Size_lv) + "k";
		}
	    }
	else if( Size_lv < Rg_p->SizeK() )
	    {
	    option.option[0].name = "remove_size";
	    option.option[0].is_number_based = false;
	    option.option[0].type = EVMS_Type_Unsigned_Int32;
	    option.option[0].flags = 0;
	    option.option[0].value.i32 = (Rg_p->SizeK()-Size_lv)*2;
	    ret = evms_shrink( Rg_p->Id(), NULL, &option );
	    if( ret )
		{
		y2milestone( "evms_shrink ret %d", ret );
		y2milestone( "ret %s", evms_strerror(ret) );
		Error_C = "could not shrink volume " + Name_Cv + " to " +
		          dec_string(Size_lv) + "k";
		}
	    }
	/*
	if( Size_lv != Rg_p->SizeK() && Rg_p->Volume()!=NULL )
	    {
	    ret = evms_delete( Rg_p->Volume()->Id() );
	    if( ret )
		{
		y2milestone( "evms_delete ret %d", ret );
		y2milestone( "ret %s", evms_strerror(ret) );
		Error_C = "could not delete volume " + Container_Cv;
		}
	    }
	*/
	}
    if( Error_C.size()==0 )
	{
	EndEvmsCommand();
	}
    if( Error_C.size()>0 )
	{
	y2milestone( "Error: %s", Error_C.c_str() );
	}
    else
	{
	y2milestone( "OK" );
	}
    return( Error_C.size()==0 );
    }

boolean EvmsAccess::EndEvmsCommand()
    {
    int ret = evms_commit_changes();
    if( ret )
	{
	y2milestone( "evms_commit_changes ret %d", ret );
	Error_C = "could not commit changes";
	}
    RereadAllObjects();
    return( ret==0 );
    }

void EvmsAccess::Output( ostream& str ) const
    {
    for( list<EvmsObject*>::const_iterator Ptr_Ci = objects.begin(); 
         Ptr_Ci != objects.end(); Ptr_Ci++ )
	{
	switch( (*Ptr_Ci)->Type() )
	    {
	    case EVMS_DISK:
	    case EVMS_SEGMENT:
	    case EVMS_REGION:
	    case EVMS_OBJ:
		str << *(EvmsDataObject*)*Ptr_Ci;
		break;
	    case EVMS_CONTAINER:
		str << *(EvmsContainerObject*)*Ptr_Ci;
		break;
	    case EVMS_VOLUME:
		str << *(EvmsVolumeObject*)*Ptr_Ci;
		break;
	    default:
		str << **Ptr_Ci;
		break;
	    }
	}
    }

ostream& operator<<( ostream &str, const EvmsAccess& obj )
    {
    obj.Output( str );
    return( str );
    }
