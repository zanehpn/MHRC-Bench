#include "stdio.h"
#ifdef __cplusplus
extern "C" {
#endif
extern char at_least_one_object_file;
extern void *kernel_scs_file_ht_new(const void *, int);
extern int kernel_scs_file_ht_get(void *, const char *, int *);
extern int  strcmp(const char*, const char*);
  typedef struct {
    char* dFileName;
  } lPkgFileInfoStruct;

  typedef struct {
    char* dFileName;
    char* dRealFileName;
    long dFileOffset;
    unsigned long dFileSize;
    int dFileModTime;
    unsigned int simFlag;
  } lFileInfoStruct;

static int lNumOfScsFiles;
  static lFileInfoStruct lFInfoArr[] = {
  {"synopsys_sim.setup_0", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 2739, 4104, 1464145427, 0},
  {"./64/SPICONTROLLER_TARGET_TB.sim", "", 0, 2739, 0, 1},
  {"./64/DUMMY_MHDL_CFG_SPICONTROLLER_TARGET_TB.sim", "", 6843, 3870, 0, 0},
  {"linux64/packages/IEEE/lib/64/STD_LOGIC_UNSIGNED__.sim", "", 10713, 85885, 0, 0},
  {"linux64/packages/IEEE/lib/64/STD_LOGIC_UNSIGNED.sim", "", 96598, 40667, 0, 0},
  {"./64/SPICONTROLLER.sim", "", 137265, 7415, 0, 1},
  {"./64/SPICONTROLLER_TARGET_TB__TB.sim", "", 144680, 32007, 0, 1},
  {"./64/SPICONTROLLER__BEHAVIORAL.sim", "", 176687, 49403, 0, 1},
  {"./64/SPICONTROLLER.mra", "", 226090, 11, 0, 0},

  };
  static lPkgFileInfoStruct lPkgFileInfoArr[] = {
  {"linux64/packages/IEEE/lib/64/STD_LOGIC_UNSIGNED__.sim"},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 9;
  lNumOfPkgSimFiles = 1;
  if (xCheckInPkgSimFiles)
  {
     for (j = 0; j < lNumOfPkgSimFiles; j++)
     {
       char* lFName;
       lFName = lPkgFileInfoArr[k].dFileName;
       if (strcmp(lFName, xFileName) == 0)
           return 0;
       k = (k + 1) % lNumOfPkgSimFiles;
     }
     return 1;
  }
  if (!ht)
  {
    ht  = kernel_scs_file_ht_new(lFInfoArr, lNumOfScsFiles);
  }
  if (ht && (kernel_scs_file_ht_get(ht, xFileName, &i) == 0))
  { /* found it! The indicator 'i' was set properly. */
    if (xRealFileName)
        *xRealFileName = lFInfoArr[i].dRealFileName;
    *xFileSizePtr = lFInfoArr[i].dFileSize;
    *xFileOffsetPtr = lFInfoArr[i].dFileOffset;
    return 0;
  }
  return 1;
}
int getNextSimFile(char **fn, long *offset)
{
  static int cur;
  for ( ; cur < lNumOfScsFiles; ) {
    if (!lFInfoArr[cur].simFlag) {
      cur++;
      continue;
    }
    *fn = lFInfoArr[cur].dFileName;
    *offset = lFInfoArr[cur].dFileOffset;
    cur++;
    return 1;
  }
  return 0;
}

#ifdef __cplusplus
}
#endif
