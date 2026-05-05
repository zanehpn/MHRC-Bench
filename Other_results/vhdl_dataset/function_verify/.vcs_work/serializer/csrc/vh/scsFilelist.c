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
  {"synopsys_sim.setup_0", "./synopsys_sim.setup", 2716, 50, 1774612599, 0},
  {"synopsys_sim.setup_1", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 2766, 4104, 1464145427, 0},
  {"./work/64/SERIALIZER_TARGET_TB.sim", "", 0, 2716, 0, 1},
  {"./work/64/DUMMY_MHDL_CFG_SERIALIZER_TARGET_TB.sim", "", 6870, 74085, 0, 0},
  {"./UNISIM/64/VCOMPONENTS.sim", "", 80955, 47173, 0, 1},
  {"./work/64/SERIALIZER.sim", "", 128128, 5348, 0, 1},
  {"./work/64/SERIALIZER_TARGET_TB__SIM.sim", "", 133476, 12614, 0, 1},
  {"./work/64/SERIALIZER__RTL.sim", "", 146090, 48153, 0, 1},
  {"./UNISIM/64/OBUFDS.sim", "", 194243, 4311, 0, 1},
  {"./UNISIM/64/OBUFDS__BEHAVIORAL.sim", "", 198554, 6283, 0, 1},
  {"./UNISIM/64/OSERDESE2.sim", "", 204837, 15801, 0, 1},
  {"./UNISIM/64/OSERDESE2__BEHAVIORAL.sim", "", 220638, 32173, 0, 1},
  {"./UNISIM/64/OSERDESE1.sim", "", 252811, 14950, 0, 1},
  {"./UNISIM/64/OSERDESE1__BEHAVIORAL.sim", "", 267761, 26409, 0, 1},
  {"./work/64/SERIALIZER.mra", "", 294170, 4, 0, 0},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 15;
  lNumOfPkgSimFiles = 0;
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
