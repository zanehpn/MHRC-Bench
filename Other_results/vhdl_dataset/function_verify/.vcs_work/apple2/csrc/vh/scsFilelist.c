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
  {"./64/APPLE2_ORIGINAL_TARGET_TB.sim", "", 0, 2739, 0, 1},
  {"./64/DUMMY_MHDL_CFG_APPLE2_ORIGINAL_TARGET_TB.sim", "", 6843, 6683, 0, 0},
  {"./64/APPLE2.sim", "", 13526, 10840, 0, 1},
  {"./64/APPLE2_ORIGINAL_TARGET_TB__TB.sim", "", 24366, 22898, 0, 1},
  {"./64/TIMING_GENERATOR.sim", "", 47264, 8756, 0, 1},
  {"./64/VIDEO_GENERATOR.sim", "", 56020, 8357, 0, 1},
  {"./64/CPU65XX.sim", "", 64377, 7341, 0, 1},
  {"./64/MAIN_ROMS.sim", "", 71718, 4141, 0, 1},
  {"./64/APPLE2__RTL.sim", "", 75859, 72069, 0, 1},
  {"./64/TIMING_GENERATOR__STUB.sim", "", 147928, 22325, 0, 1},
  {"./64/CHARACTER_ROM.sim", "", 170253, 4145, 0, 1},
  {"./64/VIDEO_GENERATOR__RTL.sim", "", 174398, 37254, 0, 1},
  {"./64/CPU65XX__STUB.sim", "", 211652, 10587, 0, 1},
  {"./64/MAIN_ROMS__STUB.sim", "", 222239, 5255, 0, 1},
  {"./64/CHARACTER_ROM__STUB.sim", "", 227494, 5271, 0, 1},
  {"./64/APPLE2.mra", "", 232765, 4, 0, 0},
  {"./64/TIMING_GENERATOR.mra", "", 232769, 5, 0, 0},
  {"./64/VIDEO_GENERATOR.mra", "", 232774, 4, 0, 0},
  {"./64/CPU65XX.mra", "", 232778, 5, 0, 0},
  {"./64/MAIN_ROMS.mra", "", 232783, 5, 0, 0},
  {"./64/CHARACTER_ROM.mra", "", 232788, 5, 0, 0},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 22;
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
