#include "stdio.h"
int main()
{
	int i; char c;

	for (i=0; i<16; i++)
			printf("reg [31:0] x%02dd1, x%02dd2, x%02dd3, x%02dd4, x%02dd5, x%02dd6, x%02dd7, x%02dd8, x%02dd9;\n",i,i,i,i,i,i,i,i,i);
			
	for (i=0; i<16; i++)
			printf("reg [31:0] c%02d, c%02dd1, c%02dd2, c%02dd3, c%02dd4, c%02dd5, c%02dd6, c%02dd7, c%02dd8, c%02dd9;\n",i,i,i,i,i,i,i,i,i,i);

	for (i=0; i<16; i++)
			printf("reg [31:0] r%02d, r%02dd1, r%02dd2, r%02dd3, r%02dd4, r%02dd5, r%02dd6, r%02dd7, r%02dd8, r%02dd9;\n",i,i,i,i,i,i,i,i,i,i);

	printf("always @ (posedge clk)\nbegin\n");

	c = 'x';
	for (i=0; i<16; i++)
	{
		printf ("%c%02dd1 <= %c%02d;\n",  c, i, c, i);
		printf ("%c%02dd2 <= %c%02dd1;\n", c, i, c, i);
		printf ("%c%02dd3 <= %c%02dd2;\n", c, i, c, i);
		printf ("%c%02dd4 <= %c%02dd3;\n", c, i, c, i);
		printf ("%c%02dd5 <= %c%02dd4;\n", c, i, c, i);
		printf ("%c%02dd6 <= %c%02dd5;\n", c, i, c, i);
		printf ("%c%02dd7 <= %c%02dd6;\n", c, i, c, i);
		printf ("%c%02dd8 <= %c%02dd7;\n", c, i, c, i);
		printf ("%c%02dd9 <= %c%02dd8;\n", c, i, c, i);
	}
	
	c = 'c';
	for (i=0; i<16; i++)
	{
		printf ("%c%02dd1 <= %c%02d;\n",  c, i, c, i);
		printf ("%c%02dd2 <= %c%02dd1;\n", c, i, c, i);
		printf ("%c%02dd3 <= %c%02dd2;\n", c, i, c, i);
		printf ("%c%02dd4 <= %c%02dd3;\n", c, i, c, i);
		printf ("%c%02dd5 <= %c%02dd4;\n", c, i, c, i);
		printf ("%c%02dd6 <= %c%02dd5;\n", c, i, c, i);
		printf ("%c%02dd7 <= %c%02dd6;\n", c, i, c, i);
		printf ("%c%02dd8 <= %c%02dd7;\n", c, i, c, i);
		printf ("%c%02dd9 <= %c%02dd8;\n", c, i, c, i);
	}
	
	c = 'r';
	for (i=0; i<16; i++)
	{
		printf ("%c%02dd1 <= %c%02d;\n",  c, i, c, i);
		printf ("%c%02dd2 <= %c%02dd1;\n", c, i, c, i);
		printf ("%c%02dd3 <= %c%02dd2;\n", c, i, c, i);
		printf ("%c%02dd4 <= %c%02dd3;\n", c, i, c, i);
		printf ("%c%02dd5 <= %c%02dd4;\n", c, i, c, i);
		printf ("%c%02dd6 <= %c%02dd5;\n", c, i, c, i);
		printf ("%c%02dd7 <= %c%02dd6;\n", c, i, c, i);
		printf ("%c%02dd8 <= %c%02dd7;\n", c, i, c, i);
		printf ("%c%02dd9 <= %c%02dd8;\n", c, i, c, i);
	}
	
	printf("end\n");
	return 0;
}
