#include <iostream>
#include <random>
#include "ex01-library.h"

using namespace std;


int countMines(Tile **field, unsigned int m, unsigned int n, int r, int c);

// Task 1(a).  Implement this function
Tile **createMinefield(unsigned int m, unsigned int n) {

    Tile **mineField = new Tile *[m];

    // Initialize subarays to get mx2m matrix 
    for(int i = 0; i < m; i ++){
        mineField[i] = new Tile[2*m]; 

        // Initialize default values
        for(int j = 0; j < n; j++){
            mineField[i][j].mine = false;
            mineField[i][j].hit = false; 
        }
    }

    return mineField;
}

// Task 1(b).  Implement this function
bool placeMine(Tile **field, unsigned int m, unsigned int n, unsigned int r, unsigned int c) {


    if(r < 0 || r > m-1){
        return false; 
    }

    if(c < 0 || c > n-1){
        return false;
    }

    if(field[r][c].mine){
        return false;
    }


    int countMines = 0;
    for(int i = 0; i < m; i++){
        for(int j = 0; j < n; j++){
            if(field[i][j].hit){
                return false; 
            }

            if(field[i][j].mine){
                countMines++;
            }

        }
    }

    if(countMines < (int) (n*m)/4){
        field[r][c].mine = true;
        return true;
    }

    return false; 
}

// Task 1(c).  Implement this function
void displayMinefield(Tile **field, unsigned int m, unsigned int n) {

    for (unsigned int row = 0; row < m; row++) {
        for (unsigned int col = 0; col < n; col++) {
            if(!field[row][col].hit){
                cout << "?"; 
            }
            else if(field[row][col].hit && field[row][col].mine){
                cout << "X";
            }
            else if(field[row][col].hit && !field[row][col].mine){
                cout << countMines(field,m,n,row,col);
            }
        }
        cout << endl;
    }

	return;
}


int countMines(Tile **field, unsigned int m, unsigned int n, int r, int c){

    int mines = 0; 

    if(r-1 >= 0 && field[r-1][c].mine){
        mines++;
    }

    if(r-1 >= 0 && c+1 < n && field[r-1][c+1].mine){
        mines++;
    }

    if(c+1 < n && field[r][c+1].mine){
        mines++;
    }

    if(r+1 < m && c+1 < n && field[r+1][c+1].mine){
        mines++;
    }

    if(r+1 < m && field[r+1][c].mine){
        mines++;
    }

    if(r+1 < m && c-1 >= 0 && field[r+1][c-1].mine){
        mines++;
    }

    if(c-1 >= 0 && field[r][c-1].mine){
        mines++;
    }

    if(r-1 >= 0 && c-1 >= 0 && field[r-1][c-1].mine){
        mines++;
    }

    return mines;

}



// Task 1(d).  Implement this function
bool isGameOver(Tile **field, unsigned int m, unsigned int n)
{
    bool allTilesTouched = false; 

     for(int i = 0; i < m; i++){
        for(int j = 0; j < n; j++){

            if(field[i][j].mine && field[i][j].hit){
                return true;
            }

            if(!field[i][j].mine && !field[i][j].hit){
                allTilesTouched = false;
            }
        }
    }


    return allTilesTouched; 
}

// Do not modify the following function.
void deleteMinefield(Tile **field, unsigned int m) {
    for (unsigned int i = 0; i < m; i++) {
        delete[] field[i];
    }
    delete[] field;
}

// Do not modify the following function.
void revealMinefield(Tile **field, unsigned int m, unsigned int n) {
    for (unsigned int row = 0; row < m; row++) {
        for (unsigned int col = 0; col < n; col++) {
            if(field[row][col].mine){
                if(field[row][col].hit){
                    cout << "X";
                } else {
                    cout << "M";
                }
            } else {
                if(field[row][col].hit){
                    cout << "E";
                } else {
                    cout << " ";
                }
            }
        }
        cout << endl;
    }
}