#ifndef EVMS_ACCESS_H
#define EVMS_ACCESS_H

#include <iostream>
#include <list>

extern "C"
{
#define bool boolean
#include <appAPI.h>
#undef bool
}

using namespace std;

typedef enum { EVMS_UNKNOWN, EVMS_DISK, EVMS_SEGMENT, EVMS_REGION, EVMS_PLUGIN,
               EVMS_CONTAINER, EVMS_VOLUME, EVMS_OBJ } ObjType;

class EvmsAccess;

class EvmsObject
    {
    public:
	EvmsObject() { Init(); };
	EvmsObject( object_handle_t id );
	virtual ~EvmsObject();

	ObjType Type() const { return type; };
	const string& Name() const { return name; };
	const object_handle_t Id() const { return id; };

	void DisownPtr() { own_ptr = false; };
	void Output( ostream& Stream ) const;
	unsigned long long SizeK() const { return size; };
	bool IsDataType() const;
	bool IsData() const { return is_data; };
	bool IsFreespace() const { return is_freespace; };
	virtual void AddRelation( EvmsAccess* Acc ) {};

    protected:
	void Init();
	bool own_ptr;
	bool is_data;
	bool is_freespace;
	unsigned long long size;
	ObjType type;
	object_handle_t id;
	string name;
	handle_object_info_t *info_p;
    };

class EvmsDataObject : public EvmsObject
    {
    public:
	EvmsDataObject( EvmsObject *const obj );
	EvmsDataObject( object_handle_t id );
	const EvmsObject *const ConsumedBy() const { return consumed; };
	const EvmsObject *const Volume() const { return volume; };
	void Output( ostream& Stream ) const;
	virtual void AddRelation( EvmsAccess* Acc );

    protected:
	void Init();
	storage_object_info_t* GetInfop();
	EvmsObject * consumed;
	EvmsObject * volume;
    };

class EvmsContainerObject : public EvmsObject
    {
    public:
	EvmsContainerObject( EvmsObject *const obj );
	EvmsContainerObject( object_handle_t id );
	unsigned long long FreeK() const { return free; };
	unsigned long long PeSize() const { return pe_size; };
	const list<EvmsObject *>& Consumes() const { return consumes; };
	const list<EvmsObject *>& Creates() const { return creates; };
	const string& TypeName() const { return ctype; };
	void Output( ostream& Stream ) const;
	virtual void AddRelation( EvmsAccess* Acc );

    protected:
	void Init();
	storage_container_info_t* GetInfop();
	unsigned long long free;
	unsigned long long pe_size;
	list<EvmsObject *> consumes;
	list<EvmsObject *> creates;
	string ctype;
    };

class EvmsVolumeObject : public EvmsObject
    {
    public:
	EvmsVolumeObject( EvmsObject *const obj );
	EvmsVolumeObject( object_handle_t id );
	const EvmsObject * ConsumedBy() const { return consumed; };
	EvmsObject * Consumes() const { return consumes; };
	const EvmsObject * AssVol() const { return assc; };
	bool Native() const { return native; };
	const string& Device() const { return device; };
	void Output( ostream& Stream ) const;
	void SetConsumedBy( EvmsObject* Obj );
	virtual void AddRelation( EvmsAccess* Acc );

    protected:
	void Init();
	logical_volume_info_s* GetInfop();
	bool native;
	EvmsObject * consumed;
	EvmsObject * consumes;
	EvmsObject * assc;
	string device;
    };

class EvmsAccess
    {
    public:
	EvmsObject *const AddObject( object_handle_t id );
	EvmsObject *const Find( object_handle_t id );
	EvmsAccess();
	~EvmsAccess();
	void Output( ostream &Stream ) const;
	void ListVolumes( list<const EvmsVolumeObject*>& l ) const;
	void ListContainer(list<const EvmsContainerObject*>& l ) const;
	string GetErrorText();
	string GetCmdLine();
	bool ChangeActive( const string& Name_Cv, bool Active_bv );
	bool DeleteCo( const string& Container_Cv );
	bool ExtendCo( const string& Container_Cv, const string& PvName_Cv );
	bool ShrinkCo( const string& Container_Cv, const string& PvName_Cv );
	bool CreateCo( const string& Container_Cv, unsigned long PeSize_lv,
		       bool NewMeta_bv, list<string>& Devices_Cv );
	bool CreateLv( const string& LvName_Cv, const string& Container_Cv,
		       unsigned long Size_lv, unsigned long Stripe_lv,
		       unsigned long StripeSize_lv );
	bool ChangeLvSize( const string& LvName_Cv, const string& Container_Cv,
	                   unsigned long Size_lv );
	bool DeleteLv( const string& LvName_Cv, const string& Container_Cv );

    protected:
	void AddObjectRelations();
	void RereadAllObjects();
	plugin_handle_t GetLvmPlugin();
	object_handle_t FindUsingVolume( object_handle_t id );
	const EvmsContainerObject* FindContainer( const string& name );
	const EvmsDataObject* FindRegion( const string& container, 
	                                  const string& name );
	static int PluginFilterFunction( const char* plugin );

	list<EvmsObject*> objects;
	boolean EndEvmsCommand();
	string Error_C;
	string CmdLine_C;
    };

extern ostream& operator<<( ostream &Stream, const ObjType Obj );
extern ostream& operator<<( ostream &Stream, const EvmsAccess& Obj );
extern ostream& operator<<( ostream &Stream, const EvmsObject& Obj );
extern ostream& operator<<( ostream &Stream, const EvmsDataObject& Obj );
extern ostream& operator<<( ostream &Stream, const EvmsContainerObject& Obj );
extern ostream& operator<<( ostream &Stream, const EvmsVolumeObject& Obj );

#endif
