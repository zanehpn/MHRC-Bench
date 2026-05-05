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
  {"synopsys_sim.setup_0", "./synopsys_sim.setup", 2976, 65, 1774947118, 0},
  {"synopsys_sim.setup_1", "/usr/synopsys/vcs-L-2016.06//bin/synopsys_sim.setup", 3041, 4104, 1464145427, 0},
  {"./work/64/AXI_RC_SERVO_CONTROLLER_ORIGINAL_TARGET_TB.sim", "", 0, 2976, 0, 1},
  {"./work/64/DUMMY_MHDL_CFG_AXI_RC_SERVO_CONTROLLER_ORIGINAL_TARGET_TB.sim", "", 7145, 18031, 0, 0},
  {"./work/64/AXI_RC_SERVO_CONTROLLER.sim", "", 25176, 14334, 0, 1},
  {"./work/64/AXI_RC_SERVO_CONTROLLER_ORIGINAL_TARGET_TB__TB.sim", "", 39510, 40325, 0, 1},
  {"./work/64/AXI_RC_SERVO_CONTROLLER__IMP.sim", "", 79835, 82412, 0, 1},
  {"./work/64/CLOCK_DIVIDER.sim", "", 162247, 4558, 0, 1},
  {"./work/64/CLOCK_DIVIDER__RTL.sim", "", 166805, 10986, 0, 1},
  {"./work/64/SERVO_CONTROLLER.sim", "", 177791, 5521, 0, 1},
  {"./work/64/SERVO_CONTROLLER__RTL.sim", "", 183312, 7416, 0, 1},
  {"./work/64/AXI_RC_SERVO_CONTROLLER.mra", "", 190728, 4, 0, 0},

  };
int gGetFileInfo(char *xFileName, long xTimeStamp, long *xFileOffsetPtr, size_t *xFileSizePtr, int xCheckInPkgSimFiles,  char **xRealFileName)
{
  int j, lNumOfPkgSimFiles;
  static void *ht = 0;
  static int i = 0;
  static int k = 0;
at_least_one_object_file = 1;
  lNumOfScsFiles = 12;
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
