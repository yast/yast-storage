#include <dlfcn.h>
#include <iostream>
#include <sstream>
#include <iterator>

#include <ycp/y2log.h>

#include "EvmsAccess.h"

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

EvmsAccess::EvmsAccess()
    {
    y2debug( "begin Konstruktor EvmsAccess" );
    unlink( "/var/lock/evms-engine" );
    int ret = evms_open_engine( NULL, (engine_mode_t)ENGINE_READWRITE, NULL, 
                                EVERYTHING, NULL );
    y2debug( "evms_open_engine ret %d", ret );
    if( ret != 0 )
	{
	y2error( "evms_open_engine evms_strerror %s", evms_strerror(ret));
	}
    else
	{
	handle_array_t* handle_p = 0;
	ret = evms_get_object_list( (object_type_t)0, (data_type_t)0,
				    (plugin_handle_t)0, (object_handle_t)0,
				    (object_search_flags_t)0, &handle_p );
	for( unsigned i=0; i<handle_p->count; i++ )
	    {
	    AddObject( handle_p->handle[i] );
	    }
	AddObjectRelations();
	evms_free( handle_p );
	}
    y2debug( "End Konstruktor EvmsAccess" );
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
