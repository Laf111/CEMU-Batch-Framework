#include <stdio.h>
#include <stdlib.h>

typedef signed long     sint32;

typedef unsigned char 	uint8;
typedef unsigned long 	uint32;

/************************ FUNCTIONS *************************/

uint32 generateHashFromRawRPXData(uint8* rpxData, sint32 size)
{
    uint32 h = 0x3416DCBF;
    for (sint32 i = 0; i < size; i++)
    {
        uint32 c = rpxData[i];
        h = (h << 3) | (h >> 29);
        h += c;
    }
    return h;
}

void display(char* file, sint32 size, uint32 nameDec)
{
//    printf("\nfile=%s\n", file);

    // display file size
//    printf("size=%ld\n", size);
    // validate : BOTW V208 EUR : shaderCacheName=3702298919;

//    printf("shaderCacheName=%ld\n", nameDec);
    char res[9]; /* four bytes of hex = 8 characters, plus NULL terminator */

    if (nameDec <= 0xFFFFFFFF)
    {
        sprintf(&res[0], "%08x", (unsigned int) nameDec);
    }

    for (uint8 i=0; i<9; i++) {
        printf("%c", res[i]);
    }
}
/*************************** MAIN ***************************/
int main(int argc, char** argv)
{
    // file size
    sint32 sz=0;
    // file data
    uint8 *rpxData=NULL;
    // shaderCacheName
    uint32 shaderCacheName=0;

    // open rpx file
    FILE *fl = fopen(argv[1], "rb");
    fseek(fl, 0, SEEK_END);
    sz = ftell(fl);

    rpxData = malloc(sz);
    if (!rpxData)
    {
        printf("Error when allocating rpxData !\n");
        return 1;
    }
    rewind(fl);

    fread(rpxData, 1, sz, fl);
    fclose(fl);

    // compute custom hash (CEMU)
    shaderCacheName=generateHashFromRawRPXData(rpxData,sz);
    // deallocation
    free(rpxData);

    display(argv[1], sz, shaderCacheName);

    return 0;
}
