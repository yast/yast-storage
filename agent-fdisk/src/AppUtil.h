// -*- C++ -*-
// Maintainer: schwab@suse.de

#ifndef _AppUtil_h
#define _AppUtil_h


#include <fstream>
#include <time.h>
#include <string>

using std::string;

#define ARRAY_SIZE(arr) (sizeof(arr)/sizeof(arr[0]))

#ifndef MAX
#define MAX(a,b) ((a) > (b) ? (a) : (b))
#endif

#ifndef MIN
#define MIN(a,b) ((a) < (b) ? (a) : (b))
#endif

#define STRING_MAXLEN 32000


class AsciiFile;

bool SearchFile(AsciiFile& File_Cr, string Pat_Cv, string& Line_Cr);
bool SearchFile(AsciiFile& File_Cr, string Pat_Cv, string& Line_Cr,
		int& StartLine_ir);
void TimeMark(const char*const Text_pcv, bool PrintDiff_bi = true);
void CreatePath(string Path_Cv);

string ExtractNthWord(int Num_iv, string Line_Cv, bool GetRest_bi = false);
void RemoveLastIf(string& Text_Cr, char Char_cv);
bool RunningFromSystem();

void Delay(int Microsec_iv);

string dec_string(long number);

#endif
