// -*- c++ -*-
// Maintainer: fehr@suse.de

#ifndef LvmAgent_h
#define LvmAgent_h

#include <scr/SCRAgent.h>
#include <Y2.h>
#include <LvmAccess.h>

/**
 * @short SCR Agent for access to lvm
 */

class LvmAgent : public SCRAgent 
{
public:
  LvmAgent();

  ~LvmAgent();

  /**
   * Reads data.
   * @param path Specifies what part of the subtree should
   * be read. The path is specified _relatively_ to Root()!
   */
  YCPValue Read( const YCPPath& path, const YCPValue& arg = YCPNull(),
                 const YCPValue& opt = YCPNull());


  /**
   * Writes data.
   */
  YCPValue Write(const YCPPath& path, const YCPValue& value, const YCPValue& arg = YCPNull());

  /**
   * Get a list of all subtrees.
   */
  YCPValue Dir(const YCPPath& path);
protected:
  YCPMap CreateLvMap( const LvInfo& Lv_Cv );
  YCPMap CreatePvMap( const PvInfo& Pv_Cv );
  YCPMap CreateVgMap( const VgInfo& Vg_Cv );
  YCPMap   Err_C;
  LvmAccess *Lvm_pC;
};


#endif // LvmAgent_h
