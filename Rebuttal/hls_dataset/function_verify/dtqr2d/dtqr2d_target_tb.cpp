
#include <cmath>
#include <cstdlib>
#include <iostream>
#include "dtqr2d.cpp"

using namespace std;

void PrintMatrix(double A[ROWS][COLS])
{
	for (int i = 0; i < ROWS; ++i)
	{
		for (int j = 0; j < COLS; ++j)
		{
			cout << A[i][j] << " ";
		}
		cout << endl;
	}
	cout << endl;
}

void PrintMatrixSquare(double A[ROWS][ROWS])
{
	for (int i = 0; i < ROWS; ++i)
	{
		for (int j = 0; j < ROWS; ++j)
		{
			cout << A[i][j] << " ";
		}
		cout << endl;
	}
	cout << endl;
}

void MM(double A[ROWS][ROWS], double B[ROWS][COLS], double C[ROWS][COLS])
{
	for (int i = 0; i < ROWS; ++i)
	{
		for (int j = 0; j < COLS; ++j)
		{
			double res = 0;
			for (int k = 0; k < ROWS; ++k)
			{
				res += A[i][k] * B[k][j];
			}
			C[i][j] = res;
		}
	}
}

void MakeEye(double A[ROWS][ROWS])
{
	for (int i = 0; i < ROWS; ++i)
	{
		for (int j = 0; j < ROWS; ++j)
		{
			if (i == j)
				A[i][j] = 1;
			else
				A[i][j] = 0;
		}
	}
}

void stream2matrix(MATRIX_T A1[LEN], MATRIX_T A2[LEN], double Target_A[ROWS][COLS])
{
	int count = 0;
	for (int i = 0; i < COLS; ++i)
	{
		for (int j = i; j < COLS; ++j)
		{
			Target_A[i][j] = A1[count];
			count++;
		}
	}

	count = 0;
	for (int i = COLS; i < ROWS; ++i)
	{
		for (int j = i - COLS; j < COLS; ++j)
		{
			Target_A[i][j] = A2[count];
			count++;
		}
	}
}

int A1_12_data[]= {242 , 135 , 120 , 123 , 194 , 234 , 120 , 125 , 216 , 34 , 182 , 215 , 244 , 1 , 66 , 100 , 237 , 201 , 180 , 155 , 28 , 199 , 13 , 140 , 208 , 56 , 68 , 194 , 12 , 105 , 245 , 4 , 23 , 38 , 178 , 103 , 96 , 86 , 91 , 118 , 142 , 244 , 174 , 80 , 106 , 225 , 111 , 89 , 114 , 217 , 100 , 224 , 75 , 77 , 195 , 92 , 38 , 221 , 167 , 200 , 214 , 78 , 218 , 198 , 172 , 138 , 75 , 85 , 145 , 96 , 128 , 70 , 111 , 61 , 247 , 75 , 25 , 153};
int A2_12_data[]= {87 , 252 , 172 , 93 , 131 , 192 , 154 , 69 , 127 , 208 , 232 , 177 , 186 , 199 , 156 , 36 , 62 , 120 , 210 , 139 , 185 , 93 , 175 , 177 , 136 , 238 , 136 , 99 , 187 , 233 , 16 , 121 , 48 , 239 , 221 , 101 , 11 , 162 , 239 , 122 , 169 , 216 , 232 , 247 , 220 , 133 , 238 , 83 , 112 , 37 , 95 , 194 , 135 , 191 , 240 , 55 , 69 , 32 , 232 , 71 , 97 , 24 , 192 , 63 , 184 , 212 , 217 , 144 , 86 , 116 , 73 , 197 , 33 , 60 , 21 , 220 , 108 , 184};

int main()
{
	MATRIX_T A1[LEN];
	MATRIX_T A2[LEN];

	for (int i = 0; i < LEN; ++i){
		A1[i] = A1_12_data[i];
		A2[i] = A2_12_data[i];
	}

	double Target_A[ROWS][COLS] = {0};
	double Q[ROWS][ROWS] = {0};

	MakeEye(Q);
	fixed_cs Q_L[Q_LEN];
	fixed_cs Q_R[Q_LEN];

	double R_re[ROWS][COLS] = {0};
	double A_re[ROWS][COLS] = {0};

	stream<MATRIX_T> A1_s;
	stream<MATRIX_T> A2_s;
	stream<fixed_cs> Q_L_s;
	stream<fixed_cs> Q_R_s;
	stream<MATRIX_T> R_s;

	cout << "Target Matrix" << endl;
	stream2matrix(A1, A2, Target_A);
	PrintMatrix(Target_A);

	for (int i = 0; i < LEN; i++){
		A1_s.write(A1[i]);
		A2_s.write(A2[i]);
	}

	int ret = top(A1_s, A2_s, Q_L_s, Q_R_s, R_s);

	for (int i = 0; i < Q_LEN; i++){
		Q_L[i] = Q_L_s.read();
		Q_R[i] = Q_R_s.read();
	}

	int count = 0;
	for (int i = 0; i < COLS; ++i)
	{
		for (int j = i; j < COLS; ++j)
		{
			R_re[i][j] = R_s.read();
			count += 1;
		}
	}

	int counts = 0;
	for (int i = 0; i < COLS; ++i)
	{
		for (int j = 0; j < i + 1; ++j)
		{
			Q[j][i] = Q_L[counts];
			Q[COLS - i - 1 + j][COLS * 2 - 1 - i] = Q_R[counts];
			counts++;
		}
		for (int j = 0; j < i + 1; ++j)
		{
			Q[j + COLS][i] = Q_L[counts];
			Q[COLS * 2 - i - 1 + j][COLS * 2 - 1 - i] = Q_R[counts];
			counts++;
		}
	}

	cout << "Matrix R: " << endl;
	PrintMatrix(R_re);

	cout << "Matrix Q: " << endl;
	PrintMatrixSquare(Q);

	MM(Q, R_re, A_re);
	cout << "Results (Q * R): " << endl;
	PrintMatrix(A_re);

	double sum_err_rate = 0.0;
	double max_err = 0.0;
	for(int i = 0; i < ROWS; ++i)
	{
		for(int j = 0; j < COLS; ++j)
		{
			double err = hls::abs(A_re[i][j] - Target_A[i][j]);
			double err_rate = Target_A[i][j] == 0 ? 0 : err / Target_A[i][j];
			sum_err_rate += err_rate;
			if (err > max_err)
				max_err = err;
		}
	}

	cout << "Sum error rate: " << sum_err_rate << endl;
	cout << "Max error: " << max_err << endl;

	if (max_err > 5.0) {
		cerr << "dtqr2d: max error too large: " << max_err << endl;
		return 1;
	}

	cout << "dtqr2d: PASS" << endl;
	return 0;
}
