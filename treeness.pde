// Treeness
import processing.pdf.*;

//int seed = 781789;
//int seed = 266001;
//int seed = 872334;
int seed = 387250;

int last_seed[] = new int[50];
int last_seed_ctr = 0;

float perturbmainmax = 15 * PI/180;
float branchperturbmax = 70 * PI/180;
float branchperturbmin = 30 * PI/180;

boolean online = false;
boolean done = false;
boolean refresh = true;
boolean stop = false;
String mode = "tree";
boolean branches = true;
boolean leaves = false;
boolean xmas = false;
boolean onebranch = false;
boolean logging = false;
boolean pdf = false;
String message = "";
int pass = 0;
int pass_tree = 0;
int pass_leaves = 1;
int gmin = 100;
boolean scaling = true;
boolean web = true;

// starting conditions
int startlen;

// startweight/oldgrowth == genmax
int startweight = 50; //40, 120 pdf
int genmax = 50; //50,  50 pdf
float oldgrowth = 0.95; // percent of generations with weight > 1
float phototrop_mod = -0.10;
float leafsize = 3.0;
int pullvec_max = 11;
PVector[][] pullvec = new PVector[pullvec_max][pullvec_max];
float pullvec_mod = 0.10;
int firstbranch = 0;
float dscale = 0;
int dwidth = 0;
int dheight = 0;
float basebranchlen = 0;
float nearbybranchprob = 0.5;

// arc
PVector arc0;
float arcmagsq;

// Critical: When a branch forks off, its diameter is between 0.5 and
// 0.75 of the trunk where it left.  Or, rather, it's between 0.25 and
// 0.5 when you think of the branch as the smaller member.  I don't
// know why the paper phrased it like that.
//
// ... or, was it right?
// 
//   from hort.ufl.edu/woody/...
float branch_ratio_max = 0.50;
float branch_ratio_min = 0.25;


// start the tree going straight up, with some wiggle room
Angle startangle = new Angle(270 * PI/180 + random(-5*PI/180, +5*PI/180), PI/2);

boolean hasbranched = false;

boolean demo = false;
boolean help = false;
boolean autopilot = false;

int bg_r = 0xff;
int bg_g = 0xff;
int bg_b = 0xff;
int fg_r = 0x00;
int fg_g = 0x00;
int fg_b = 0x00;

int framenum = 0;

// Angle
//
//  Used throughout to capture the branching angle in spherical
//  coordinates.
//
class Angle
{
    float theta;
    float phi;

    Angle (float t, float p) {
        theta = t;
        phi = p;
    }
    Angle (Angle a) {
        theta = a.theta;
        phi = a.phi;
    }
    Angle () {
        theta = 0;
        phi = 0;
    }
    
    // fix
    //
    //   Normalizes the angle to be in the range [0, 2*PI).
    //
    void fix() {
        if (theta < 0) {
            theta += TWO_PI;
        }
        else if (theta >= TWO_PI) {
            theta -= TWO_PI;
        }
        if (phi < 0) {
            phi += TWO_PI;
        }
        else if (phi >= TWO_PI) {
            phi -= TWO_PI;
        }
    }
}

class Frame
{
    PVector p;
    Angle a;
    int generation;
    float remain;
    boolean initialized;
    float trunkremain;

    Frame() {
        initialized = false;
    }
    
    Frame(PVector p_in, Angle a_in, int generation_in, float remain_in, float trunkremain_in) {
        p = p_in;
        a = a_in;
        generation = generation_in;
        remain = remain_in;
        initialized = true;
        trunkremain = trunkremain_in;
    }

    void save(PVector p_in, Angle a_in, int generation_in, float remain_in, float trunkremain_in) {
        p = p_in;
        a = a_in;
        generation = generation_in;
        remain = remain_in;
        initialized = true;
        trunkremain = trunkremain_in;
    }
    
    void resume() {
        initialized = false;
        grow(p, a, generation, remain, trunkremain, 0);
    }
}

Frame lastframe = new Frame();
boolean popping = false;
int gensleftmax = 3;
int gensleft = gensleftmax;

////////////////////////////////////////////////////////////////////////
// Processing Callbacks
////////////////////////////////////////////////////////////////////////

void setup()
{
//    size(6000,4000);
//    web = false;
    size(700, 600);
    web = true;
    if (online) {
        web = true;
    }
    smooth();
    stroke(0);
    PFont h15 = loadFont("Helvetica-15.vlw");
    textFont(h15, 15);
    frameRate(30);
    arc0 = new PVector(0, -0.20 * height, 0);
    arcmagsq = 0.80 * height * 0.80 * height;

    // ESTABLISH DEFAULT PARAMETERS
    if (web) {
        webdefaults();
    }
    else {
        defaults(); 
    }

    init_randangle_hole(branchperturbmin, branchperturbmax, 60*PI/180);
    random_A_init();
    random_B_init();

    // initialize the "pull" vector that pulls branches away from the tree
    float wid_to_max = float(width)/float(pullvec_max);
    for (int i=0; i<pullvec_max; i++) {
        for (int j=0; j<pullvec_max; j++) {
            float x = int(float(i) * wid_to_max - width/2);
            float z = int(float(j) * wid_to_max - width/2); // yes, width
            PVector cyl = new PVector();
            float r = sqrt(x*x + z*z);
            if (r < wid_to_max*2) {
                // skip center
                cyl.x = 0;
                cyl.y = 0;
                cyl.z = 0;
            }
            else {
                cyl.x = x;
                cyl.y = 0;
                cyl.z = z;
                cyl.normalize();
            }
            pullvec[i][j] = cyl;
        }
    }
}

void draw()
{
    boolean screenpass = true;
    stroke(fg_r, fg_g, fg_b);
    fill(0);
    if (refresh) {
        if (demo) {
            onebranch = false;
            branches = true;
            help = false;
        }
        if (pdf) {
            beginRecord(PDF, "tree-####.pdf");
            dwidth = width;
            dheight = height;
            dscale = 1.0;
        }
        else {
            if (scaling && height > 800) {
                dscale = 800.0/float(height);
                dwidth = int(dscale * width);
                dheight = int(dscale * height);
            }
            else {
                dwidth = width;
                dheight = height;
                dscale = 1.0;
            }
        }
        background(bg_r, bg_g, bg_b);
        if (!demo) {
            if (logging) {
                println("DRAW TOP -------------------------------------------------------------------------");
            }
            if (help) {
                textblock();
//                weightGraph(int(0.6666667 * width), int(0.15 * height), 3);
//                branchAtGraph(int(0.6666667 * width), int(0.25 * height), 3);
//                lengthGraph(int(0.6666667 * width), int(0.45 * height), 3);
            }
        }
        refresh = false;
        done = false;
        lastframe.initialized = false;
        gensleft = gensleftmax;
        popping = false;
        pass = pass_tree;
        framenum = 0;
    }

    // 
    while ((pdf || screenpass) && !done) {
        hasbranched = false;
    
        if (!done) {
            randomSeed(seed);
            if (message != "" && !pdf) {
                fill(255, 80, 80);
                text(message, 20, 20);
                fill(255);
                message = "";
            }
            if (mode == "tree") {
                // start tree in mid-bottom once/frame
                if (screenpass) {
                    translate(dwidth/2, dheight);
                }
                
                stroke(fg_r, fg_g, fg_b);
                fill(fg_r, fg_g, fg_b);
            
                PVector origin = new PVector(0, 0, 0);
                popping = false;
                gensleft = gensleftmax;
                if (lastframe.initialized) {
                    lastframe.resume();
                }
                else {
                    grow(origin, startangle, 1, firstbranch, 0, 0);
                }
                if (!lastframe.initialized) {
                    if ((leaves || xmas) && pass < pass_leaves) {
                        pass++;
                    }
                    else {
                        pass = pass_tree;
                        done = true;
                    }
                }
                screenpass = false;
            }
            else if (mode == "leaf") {
                int x, y;
                for (x=0; x<width; x+=100) {
                    for (y=0; y<height; y+=100) {
//                    twistyLeaf(x+25, y+25, 0, 90*PI/180, 10);
                    }
                }
                done = true;
            }
        }
    }
    
    if (pdf) {
        endRecord();
        pdf = false;
        refresh = true;
        message = "screen written to tree.pdf";
    }
    if (stop && !online) {
        exit();
    }
    if (autopilot && framenum++ > 900) {
        newSeed();
        refresh = true;
    }
    
}

void newSeed()
{
    last_seed[last_seed_ctr] = seed;
    last_seed_ctr++;
    if (last_seed_ctr >= last_seed.length) {
        last_seed_ctr = 0;
    }
    seed = int(random(0,1000000));
    refresh = true;
}

void prevSeed()
{
    last_seed_ctr--;
    if (last_seed_ctr < 0) {
        last_seed_ctr = last_seed.length-1;
    }
    seed = last_seed[last_seed_ctr];
    refresh = true;
}

void mousePressed()
{
    newSeed();
    autopilot = false;
}

void keyPressed()
{
    if (key == 'd') {
        if (demo) {
            demo = false;
            autopilot = false;
        }
        else {
            demo = true;
            autopilot = true;
        }
        refresh = true;
        return;
    }
    else if (key == 'n' || key == ' ') {
        newSeed();
        autopilot = false;
    }
    
    if (demo) {
        return;
    }
    
    if (key == '8' && !online) {
        if (mode == "tree") {
            mode = "leaf";
        }
        else {
            mode = "tree";
        }
        refresh = true;
    }
    else if (key == 'f') {
        leafsize -= 0.25;
        if (leafsize <= 0) {
            leafsize = 0.25;
        }
        refresh = true;
    }
    else if (key == 'F') {
        leafsize += 0.25;
        refresh = true;
    }
    else if (key == 'b') {
        if (branches) {
            branches = false;
        }
        else {
            branches = true;
        }
        refresh = true;
    }
    else if (key == 'h') {
        if (help) {
            help = false;
        }
        else {
            help = true;
        }
        refresh = true;
    }
    else if (key == 'v') {
        if (leaves) {
            leaves = false;
        }
        else {
            leaves = true;
        }
        refresh = true;
    }
    else if (key == 'x') {
        if (xmas) {
            xmas = false;
        }
        else {
            xmas = true;
        }
        refresh = true;
    }
    else if (key == '1') {
        if (onebranch) {
            onebranch = false;
        }
        else {
            onebranch = true;
        }
        refresh = true;
    }
    else if (key == '$') {
        if (scaling) {
            scaling = false;
        }
        else {
            scaling = true;
        }
        refresh = true;
    }
    else if (key == 'P') {
        phototrop_mod += 0.10;
        refresh = true;
    }
    else if (key == 'p') {
        phototrop_mod -= 0.10;
        refresh = true;
    }
    else if (key == 'U') {
        pullvec_mod += 0.10;
        refresh = true;
    }
    else if (key == 'u') {
        pullvec_mod -= 0.10;
        refresh = true;
    }
    else if (key == 'R') {
        gmin -= 5;
        if (gmin <= 5) {
            gmin = 5;
        }
        refresh = true;
    }
    else if (key == 'r') {
        gmin += 5;
        refresh = true;
    }
    else if (key == 'Y') {
        nearbybranchprob += 0.05;
        if (nearbybranchprob > 1.0) {
            nearbybranchprob = 1.0;
        }
        refresh = true;
    }
    else if (key == 'y') {
        nearbybranchprob -= 0.05;
        if (nearbybranchprob < 0.05) {
            nearbybranchprob = 0.05;
        }
        refresh = true;
    }
    else if (key == 'E') {
        basebranchlen += 5;
        refresh = true;
    }
    else if (key == 'e') {
        basebranchlen -= 5;
        if (basebranchlen <= 5) {
            basebranchlen = 5;
        }
        refresh = true;
    }
    else if (key == 'M') {
        branch_ratio_max += 0.05;
        if (branch_ratio_max > 1.0) {
            branch_ratio_max = 1.0;
        }
        refresh = true;
    }
    else if (key == 'm') {
        branch_ratio_max -= 0.05;
        if (branch_ratio_max < 0.05) {
            branch_ratio_max = 0.05;
        }
        refresh = true;
    }
    else if (key == 'G') {
        genmax += 5;
        refresh = true;
    }
    else if (key == 'g') {
        genmax -= 5;
        if (genmax < 5) {
            genmax = 5;
        }
        refresh = true;
    }
    else if (key == 'W') {
        startweight += 4;
        refresh = true;
    }
    else if (key == 'w') {
        startweight -= 4;
        if (startweight < 4) {
            startweight = 4;
        }
        refresh = true;
    }
    else if (key == 'A') {
        firstbranch += 10;
        if (firstbranch > height) {
            firstbranch = height;
        }
        refresh = true;
    }
    else if (key == 'a') {
        firstbranch -= 10;
        if (firstbranch < 10) {
            firstbranch = 10;
        }
        refresh = true;
    }
    else if (key == 'L') {
        startlen += 2;
        refresh = true;
    }
    else if (key == 'l') {
        startlen -= 2;
        if (startlen < 2) {
            startlen = 2;
        }
        refresh = true;
    }
    else if (key == 'q' && !online) {
        stop = true;
    }
    else if (key == '&') {
        if (web) {
            webdefaults();
        }
        else {
            defaults();
        }
    }
    else if (key == '!' && !online) {
        // write a PDF
        pdf = true;
        demo = false;
        help = false;
        refresh = true;
    }
    else if (!online && key == '9') {
        if (logging) {
            logging = false;
        }
        else {
            logging = true;
        }
        refresh = true;
    } 
    else if (key == DELETE || key == BACKSPACE) {
        prevSeed();
    }
//     else if (key == CODED) {
//         if (keyCode == LEFT) {
//             refresh = true;
//         }
//         else if (keyCode == RIGHT) {
//             refresh = true;
//         }
//     }
}

////////////////////////////////////////////////////////////////////////
// Internal Functions
////////////////////////////////////////////////////////////////////////
void textblock()
{
    int skip = 20;
    int x = skip;
    int y = skip + skip; // skip message too

    if (bg_r < 100) {
        fill(255);
    }
    else {
        fill(100);
    }
    text("resolution: " + width + "x" + height + ", (" + dwidth + "x" + dheight + " scaled, factor " + dscale + ")", x, y); y += skip;
    text("[gG] max gen: " + nfc(genmax), x, y); y += skip;
    text("[wW] startweight: " + nfc(startweight), x, y); y += skip;
    text("[lL] startlen: " + nfc(startlen), x, y); y += skip;
    text("[n]  seed: " + nfc(seed), x, y); y += skip;
    text("[pP] phototrop: " + nfp(phototrop_mod, 2, 1), x, y); y+=skip;
    text("[uU] pull: " + nfp(pullvec_mod, 2, 1), x, y); y+=skip;
    text("[yY] probabilty of nearby branch: " + nfp(nearbybranchprob, 1, 2), x, y); y+=skip;
    text("[eE] base dist. between branches: " + nfp(basebranchlen, 2, 1), x, y); y+=skip;
    text("[fF] leaf size: " + nfp(leafsize, 2, 1), x, y); y+=skip;
    text("[rR] redness: " + gmin, x, y); y+=skip;
    text("[aA] first brAnch height: " + nfp(firstbranch, 2, 1), x, y); y+=skip;
    text("[mM] max branch ratio: " + nfp(branch_ratio_max, 0, 2), x, y); y+=skip;
    text("[v] leaves", x, y); y+=skip;
    text("[x] xmas", x, y); y+=skip;
    if (!online) {
        text("[9] logging", x, y); y+=skip;
        text("[$] scaling", x, y); y+=skip;
        text("[!] export to PDF", x, y); y+=skip;
        text("[1] one branch", x, y); y+=skip;
        text("[b] no branches", x, y); y+=skip;
    }
    text("[&] defaults", x, y); y+=skip;
    text("[h] no help", x, y); y+=skip;
    text("[del] back to prior tree", x, y); y+=skip;
    // 8 is "mode"
}

// defaults
//
//   Restore default settings.
void defaults() 
{
    branchperturbmax = 70 * PI/180;
    done = false;
    refresh = true;
    stop = false;
    mode = "tree";
    branches = true;
    leaves = false;
    xmas = false;
    onebranch = false;
    logging = false;
    startlen = height/50;
    startweight = 50; //40, 120 pdf
    genmax = 65; //50,  50 pdf
    oldgrowth = 0.90; // percent of generations with weight > 1
    phototrop_mod = -0.10;
    leafsize = 3.0;
    firstbranch = int(0.20 * height);
    basebranchlen = 6 * startlen;
    nearbybranchprob = 0.5;
    gmin = 100;
    scaling = true;
    autopilot = false;
}

void webdefaults() 
{
    if (online) {
        demo = true;
    }
    help = false;
    seed = 428520;
    branchperturbmax = 70 * PI/180;
    done = false;
    refresh = true;
    stop = false;
    mode = "tree";
    branches = true;
    leaves = true;
    xmas = false;
    onebranch = false;
    logging = false;
    startlen = 12;
    startweight = 22; //40, 120 pdf
    genmax = 75; //50,  50 pdf
    oldgrowth = 0.90; // percent of generations with weight > 1
    phototrop_mod = +0.10;
    leafsize = 1.8;
    firstbranch = int(0.20 * height);
    basebranchlen = 87.0;
    nearbybranchprob = 0.35;
    gmin = 100;
    scaling = true;
    branch_ratio_max = 0.75;
    bg_r = 0x49; // 0xdd;
    bg_g = 0x17; //0x9a;
    bg_b = 0x02; //0x30;
    fg_r = 148;
    fg_g = 105;
    fg_b = 64;
    autopilot = false;

    // greyish 148 105 64
    // curry 0xdd 0x9a 0x30
    // chocolate 0x49 0x17 0x02
}


// Weightfromgeneration
//   
//   Smoothly shrink the weight as the generation grows.  uses
//   oldgrowth percentage, so the last N percent of the generations
//   will have weight = 1
//
float weightFromGeneration(int generation)
{
    float weight = 1.0;
    float gwfactor = (oldgrowth * genmax)/startweight;
    if (generation/gwfactor < startweight) { 
        weight = startweight - (generation - 1)/gwfactor;
    }
    return weight;
}

// nextBranchGeneration
//
//   Figure out what the generation of this new branch should be,
//   based on the diameter ratio.
//
int nextBranchGeneration(float ratio, int generation)
{
    float w = weightFromGeneration(generation);
    int retgen;
    if (w > 1.0) {
        retgen = int((1.0 - ratio*w/startweight)*oldgrowth*genmax + 1.0); // weightFromGeneration solved for gen
    }
    else {
        retgen = generation + 1;
    }
    if (retgen < generation) {
        stop = true;
    }
    return retgen;
}

float baseLengthFromGen(int generation)
{
//    float baselen = startlen - (startlen*(generation-1))/genmax;
//    println("baseeeeeeee: " + baselen);
//     if (generation < (1.0 * genmax)) {
//         return startlen;
//     }
//     else {
//         return startlen/2;
//     }

    return startlen;
}

float lengthFromGenerationLin(int generation)
{
    float baselen = baseLengthFromGen(generation);
    
//    float len = 0.5*baselen + random(0.0, 0.5*baselen);

//    float baselen = startlen/2;
//    float len = baselen/2 + random(0.0, baselen/2);
    return gauss(baselen, baselen);
}

// float lengthFromGenerationRecip(int generation)
// {
//     int baselen = int(startlen/sqrt(generation));
//     float len = 0.5*baselen + random(0.0, 0.5*baselen);
//     return len;
// }

float perturbAngleFromGeneration(int generation)
{
    float gt = perturbmainmax * generation / genmax;
    //return random(-gt, gt);
    return gauss(0, gt);
    
}

void nextAngle(PVector p, Angle a, int generation, int level)
{
    boolean pull = false;
    a.theta += perturbAngleFromGeneration(generation);
    a.phi += perturbAngleFromGeneration(generation);
    if (level > 0) {
        pull = true;
    }
    phototropism_adjustment(p, a, pull);
}


float baseBranchAt(int generation)
{
    float branchlen = basebranchlen;
    float fudge = 1;
    
//    float baselen = -(branchlen/genmax) * (generation - 1) + branchlen;

    // sqrt(a - b*x^2)
    // y intercept = sqrt(a)
    // x intercept = sqrt(a/b)
    float a = branchlen * branchlen;
    float b = a/((genmax-fudge)*(genmax-fudge));
    float g = b*generation*generation;
    
    if (g > a) { // safety
        return 0;
    }
    else {
        return sqrt(a - g);
    }
}

float branchAt(int generation)
{
    // wider has less chance of branching

// FAIL:
//  int baselen = int(startlen*10/pow(generation, 1.61803399));
//  float len = 0.5*baselen + random(0.0, 0.5*baselen);
//    float branchlen = 7 * startlen;
//    float baselen = -(branchlen/genmax) * (generation - 1) + branchlen;
//    float len = 0.5*baselen + random(0.0, 0.5*baselen);
    float baselen = baseBranchAt(generation);
    return gauss(baselen, baselen);
}

// branchNear
//
//    Determine if the trunk should grow another branch nearby the
//    last branch.  Probability of 0.50 would be one in two chance
//    that it would.  If return is negative, don't branch.
float branchNear(int generation, float probability)
{
    if (random(0, 1/probability) >= 1) {
        return -1;
    }
    else {
        return random(0, baseBranchAt(generation)/8);
    }
}

// branch
//
//   Forks off a branch at the position p from a trunk flowing at
//   angle a.  Modifies angle a of the main trunk to push off of the
//   branch that forked off.  Returns the ratio of the cross-sectional
//   area consumed by the branch.
float branch(PVector p, Angle a, int generation, int level)
{
    if (logging) {
        println(level + ": branching: generation " + generation + ", weight " + weightFromGeneration(generation) + ", level " + level);
    }
    
    float ratio = random(branch_ratio_min, branch_ratio_max);
    int brgen = nextBranchGeneration(ratio, generation);
    float w = weightFromGeneration(generation);

    // compute the remaining diameter of the trunk, preserving the
    // cross-sectional area
    float branch_area_sq = (ratio*w)*(ratio*w);
    w = sqrt(w*w - branch_area_sq);
    float wratio = sqrt(branch_area_sq)/w;
    if (wratio > 1.0) {
        wratio = 1.0;
    }
    wratio *= 0.5;
    
    brgen -= (brgen - generation)/2; // it's not as bad as it seems

//    println("BRANCH -----------------------------------------------------------");
//    println("      trunk: " + coordstr(p, a));
//    
//    println("norm branch: " + coordstr(p, normangle));
//    println("    br. mod: " + coordstr(p, brmod));
//    println("  trunk mod: " + coordstr(p, amod));

    // Select a branching angle "ba" from a funky distribution of
    // points around the current trunk angle "a".
    Angle ba = randangle_hole(a, level);
    ba.fix();

    // Determine the vector that starts at the tip of the branch angle
    // and ends at the tip of the trunk angle.  This is then scaled by
    // the ratio found above to push the trunk angle away from the
    // branching angle.  The greater the ratio, the more the trunk
    // is pushed away from the branch.
    PVector bap = cart(1, ba);
    PVector ap = cart(1, a);
    PVector pushv = PVector.sub(ap, bap);
    pushv.mult(wratio); 
    ap.add(pushv);
    ap.normalize();
    spherical(ap, a);
    a.fix();

    // If this is the main trunk, find the branching angle as
    // projected onto the x-z plane.  Record it in the last angle
    // history. 
    if (level == 0) {
        last_angle_push(atan2(bap.z, bap.x));
    }

//    println("     branch: " + coordstr(p, ba));
//    println("  trunk new: " + coordstr(p, a));

    grow(p, ba, brgen, branchAt(brgen), 0, level+1); // skip generation on branching
    
    return w;
}


// Leaf stuff //////////////////////////////////////////////////////////
void setFallColor()
{
    int grange = 70;
    int gmax = gmin + grange;
    if (gmax > 255) {
        gmax = 255;
    }
    int red = 255;
    int green = int(random_A(gmin, gmax));
    int blue = 20;
    stroke(red, green+20, blue+20);
    fill(red, green, blue);
}

void polarLine(int x, int y, float theta, float len)
{
    int tox = x + int(len*cos(theta));
    int toy = y - int(len*sin(theta));
    line(dscale*x, dscale*y, dscale*tox, dscale*toy);
}

void polarVertex(int x, int y, float theta, float len)
{
    int tox = x + int(len*cos(theta));
    int toy = y - int(len*sin(theta));
    vertex(tox, toy);
}

void leaf(int x, int y, float theta)
{
    float n = leafsize * dscale;
    x *= dscale;
    y *= dscale;
    setFallColor();
    beginShape();
    vertex(x, y);                                 //0
    polarVertex(x, y, theta - 95*PI/180, n*2.50); //1
    polarVertex(x, y, theta - 80*PI/180, n*2.00); //2
    polarVertex(x, y, theta - 67*PI/180, n*4.25); //3
    polarVertex(x, y, theta - 58*PI/180, n*3.25); //4
    polarVertex(x, y, theta - 40*PI/180, n*5.00); //5
    polarVertex(x, y, theta - 27*PI/180, n*3.00); //6
    polarVertex(x, y, theta - 18*PI/180, n*4.75); //7
    polarVertex(x, y, theta -  8*PI/180, n*4.25); //8
    polarVertex(x, y, theta -  0*PI/180, n*6.00); //9 top
    polarVertex(x, y, theta +  8*PI/180, n*4.25); //8
    polarVertex(x, y, theta + 18*PI/180, n*4.75); //7
    polarVertex(x, y, theta + 27*PI/180, n*3.00); //6
    polarVertex(x, y, theta + 40*PI/180, n*5.00); //5
    polarVertex(x, y, theta + 58*PI/180, n*3.25); //4
    polarVertex(x, y, theta + 67*PI/180, n*4.25); //3
    polarVertex(x, y, theta + 80*PI/180, n*2.00); //2
    polarVertex(x, y, theta + 95*PI/180, n*2.50); //1
    endShape(CLOSE);
}

void twistyLeafBase(PVector p, Angle a)
{
    if (pass == pass_tree) {
        return;
    }
    float theta = polar_projection(a);
    float ltheta;
    PVector pout = new PVector();
    setFallColor();
    float ang = random_B(20, 60);
    println(" : leaf");
    ltheta = twistyLeafStem(p, theta, pout);
    twistyLeaf(pout, ltheta);
//     ltheta = twistyLeafStem(p, theta-ang, pout);
//     twistyLeaf(pout, ltheta);
//     ltheta = twistyLeafStem(p, theta+ang, pout);
//     twistyLeaf(pout, ltheta);
}

float twistyLeafStem(PVector pin, float theta, PVector pout)
{
    PVector p = new PVector(pin.x, pin.y, 0);
    Angle a = new Angle(theta, 0);
    PVector forcevec = new PVector(0, leafsize/2, 0);
    float len = 6*leafsize/2;
    float seg = len/3.0;
    pout.x = pin.x;
    pout.y = pin.y;
    for (float l=seg; l<=len; l+=seg) {
        // unit vector for next direction of stem
        PVector segvec = cart2d(seg, a);
        pout.add(segvec); // set next coordinates
        pout.add(forcevec); // apply droopy force

        // draw 
        line(dscale * p.x, dscale * p.y, dscale * pout.x, dscale * pout.y);

        // compute next angle
        segvec = PVector.sub(pout, p);
        polar(segvec, a); // throw away magnitude
        p.x = pout.x;
        p.y = pout.y;
    }

    return a.theta;
}

void twistyLeaf(PVector p, float theta)
{
    float n = leafsize * dscale;
    int x = int(p.x *dscale);
    int y = int(p.y * dscale);
    float fs = random_B(0.00, 0.80); // foreshortening
    float ls = random_B(0.00, 0.80); // left size
    float rs = random_B(0.00, 0.80); // right size
    float A = n*(1 - 0.00*fs)*(1 - 1.00*ls);
    float B = n*(1 - 0.25*fs)*(1 - 0.75*ls);
    float C = n*(1 - 0.50*fs)*(1 - 0.50*ls);
    float D = n*(1 - 0.75*fs)*(1 - 0.25*ls);
    float E = n*(1 - 1.00*fs);               //center
    float F = n*(1 - 0.75*fs)*(1 - 0.25*rs);
    float G = n*(1 - 0.50*fs)*(1 - 0.50*rs);
    float H = n*(1 - 0.25*fs)*(1 - 0.75*rs);
    float I = n*(1 - 0.00*fs)*(1 - 1.00*rs);
    theta += random_B(-30*PI/180, +30*PI/180); // perturb theta
    beginShape();
    vertex(x, y);                                 //0
    polarVertex(x, y, theta - 95*PI/180, A*2.50); //1
    polarVertex(x, y, theta - 80*PI/180, A*2.00); //2
    polarVertex(x, y, theta - 67*PI/180, B*4.25); //3
    polarVertex(x, y, theta - 58*PI/180, B*3.25); //4
    polarVertex(x, y, theta - 40*PI/180, C*5.00); //5
    polarVertex(x, y, theta - 27*PI/180, C*3.00); //6
    polarVertex(x, y, theta - 18*PI/180, D*4.75); //7
    polarVertex(x, y, theta -  8*PI/180, D*4.25); //8
    polarVertex(x, y, theta -  0*PI/180, E*6.00); //9 top
    polarVertex(x, y, theta +  8*PI/180, F*4.25); //8
    polarVertex(x, y, theta + 18*PI/180, F*4.75); //7
    polarVertex(x, y, theta + 27*PI/180, G*3.00); //6
    polarVertex(x, y, theta + 40*PI/180, G*5.00); //5
    polarVertex(x, y, theta + 58*PI/180, H*3.25); //4
    polarVertex(x, y, theta + 67*PI/180, H*4.25); //3
    polarVertex(x, y, theta + 80*PI/180, I*2.00); //2
    polarVertex(x, y, theta + 95*PI/180, I*2.50); //1
    endShape(CLOSE);
}


// Christmas stuff //////////////////////////////////////////////////////////
void setXmasColor()
{
    float redness = random_A(0, 1);
    int r = 0;
    int g = 0;
    int b = 0;

    if (redness >= 0.5) {
        r = 255;
    }
    else {
        g = 255;
    }
    
    stroke(r, g, b);
    fill(r, g, b);
}

void ornament(PVector p)
{
    if (random_A(0.0, 1.0) >= 0.01) {
        return; // no ornament
    }
    setXmasColor();
    float n = leafsize * dscale * 3.0;
    int x = int(p.x *dscale);
    int y = int(p.y * dscale);
    line(x, y, x, y+int(n/2.0));
    beginShape();
    for (float theta = 0.0; theta < 2.0*PI; theta += PI/16.0) {
        polarVertex(x, y + int(n*1.5), theta, n);
    }
    polarVertex(x, y + int(n*1.5), 0.0, n);
    endShape(CLOSE);
}

// grow
// 
//  Recursive entry point for growing a tree.  Grow the current trunk
//  starting at position "p", headed at angle "a".  
//
void grow(PVector p, Angle a, int generation, float remain, float trunkremain, int level)
{
    boolean istrunk = false;

    // pop the stack if requested.
    if (stop || popping) {
        return;
    }
    
    // end recursion at generation limit
    if (generation > genmax) {
        if (logging) {
            println(level + ": tip");
        }
        if (leaves) {
            twistyLeafBase(p, a);
//            twistyLeaf(int(p.x), int(p.y), int(p.z), polar_projection(a), leafsize);
//            leaf(int(p.x), int(p.y), a.theta);
        }
        if (xmas) {
            ornament(p);
        }
        stroke(fg_r, fg_g, fg_b);
        fill(fg_r, fg_g, fg_b);
        return;
    }

    // If back at the main trunk, possibly provide display refresh to
    // the viewer.  Don't do display refresh if drawing to a PDF file.
    if (level == 0) {
        if (gensleft-- == 0) {
            if (logging) {
                println(level + ": saving");
            }
            popping = true;
            lastframe.save(p, a, generation, remain, trunkremain);
            return;
        }
    }
    
    if (!demo && logging) {
        if (level == 0) {
            println(level + ": growing trunk: gen " + generation + ", remain " + nfp(remain, 3,1) + ", trunkremain " + nfp(trunkremain, 3, 1));
        }
        else {
            println(level + ": growing      : gen " + generation + ", remain " + nfp(remain, 3,1) + ", trunkremain " + nfp(trunkremain, 3, 1));
        }
    }

    // handle branching, if any
    if (remain <= 1.0 && branches) {
        float w = weightFromGeneration(generation);
//         && (w < (0.80 * startweight))
        if (!hasbranched) {
            istrunk = true;
            hasbranched = true;
        }
        float neww = branch(p, a, generation, level);
        // modify trunk's generation to account for area consumed
        // by branch.  Angle was modified by branching too!
        int newgen = nextBranchGeneration(neww/w, generation);
        int oldgen = generation;
        generation = newgen - (newgen - generation)/2;
        remain = branchNear(generation, nearbybranchprob);
        if (remain < 0) {
            remain = branchAt(generation); // set up next branch point
                                           // for reals
            if (logging) {
                println(level + ": done branching: Next branch at " + remain + ", generation now " + generation + ", was " + oldgen);
            }
        }
        else {
            if (logging) {
                println(level + ": done branching: Next branch nearby at " + remain + ", generation now " + generation + ", was " + oldgen);
            }
        }
    }

    if (onebranch && istrunk && hasbranched) {
        return;
    }

    PVector np = new PVector(p.x, p.y, p.z);
    PVector mp = new PVector();
    float len;
    
    // handle any remaining part of this generation's trunk to grow
    if (trunkremain > 0) {
        // It's possible that there's yet another branch that needs to
        // happen before this segment is out.  
        len = trunkremain;
        if (len > remain && branches) {
            trunkremain = len - remain;
            len = remain;
        }
        else {
            trunkremain = 0;
        }
        remain -= len;

        // compute the endpoint
        mp = cart(len, a);
        np.add(mp);

        // draw
        if (pass == pass_tree) {
            strokeWeight(dscale*weightFromGeneration(generation));
            line(dscale*p.x, dscale*p.y, dscale*np.x, dscale*np.y); // leave off z component,
                                                                    // projection on x-y plane
        }
        
        // If there's another branch to do before finishing this
        // segment, recurse, but keep the same generation.
        if (trunkremain > 0) {
            if (logging) {
                println(level + ": RECURSING to do another branch in generation " + generation);
            }
            grow(np, a, generation, remain, trunkremain, level);
            return;
        }
    }
    trunkremain = 0;
    
    // Compute the next trunk segment's angle.
    Angle na = new Angle(a.theta, a.phi);
    nextAngle(np, na, generation, level);

    // Compute the next trunk segment's length
    len = lengthFromGenerationLin(generation);
    if (len > remain && branches) {
        // if we'll branch before the end of the segment, save the
        // rest aside.
        trunkremain = len - remain;
        len = remain;
    }
    remain -= len;

    // ...and set the endpoint
    mp = cart(len, na);
    np.add(mp);

    // draw the segment until its end or until it needs to branch
    if (pass == pass_tree) {
        //    setFallColor();
        strokeWeight(dscale*weightFromGeneration(generation));
        line(dscale*p.x, dscale*p.y, dscale*np.x, dscale*np.y); // leave off z component, projection
                                                                // on x-y plane
    }
    
    grow(np, na, generation+1, remain, trunkremain, level);
}

void weightGraph(int x0, int y0, int scale)
{
//    println("weight graph: " + x0 + " " + y0 + " " + scale);
    stroke(0);
    strokeWeight(1);
    line(x0, y0, x0, y0 - (scale*startweight));
    line(x0, y0, x0 + (scale*genmax), y0);
    strokeWeight(2);
    
    int i;
    for (i=2; i<genmax; i++) {
        line(x0 + (scale*(i-1)), y0 - weightFromGeneration(i-1), x0 + (scale*(i)), y0 - weightFromGeneration(i));
//        println(scale*(i-1) + " " + weightFromGeneration(i-1));
        
    }
}

void branchAtGraph(int x0, int y0, int scale)
{
//    println("branchAt graph: " + x0 + " " + y0 + " " + scale);
    stroke(0);
    strokeWeight(1);
    line(x0, y0, x0, y0 - (scale*baseBranchAt(1)));
    line(x0, y0, x0 + (scale*genmax), y0);
    strokeWeight(2);
    
    int i;
    for (i=2; i<genmax; i++) {
        line(x0 + (scale*(i-1)), y0 - baseBranchAt(i-1), x0 + (scale*(i)), y0 - baseBranchAt(i));
//        println(scale*(i-1) + " " + baseBranchAt(i-1) + " to " + baseBranchAt(i));
        
    }
}


void lengthGraph(int x0, int y0, int scale)
{
//    println("lengthAt graph: " + x0 + " " + y0 + " " + scale);
    stroke(0);
    strokeWeight(1);
    line(x0, y0, x0, y0 - (scale*baseLengthFromGen(1)));
    line(x0, y0, x0 + (scale*genmax), y0);
    strokeWeight(2);
    
    int i;
    for (i=2; i<genmax; i++) {
        line(x0 + (scale*(i-1)), y0 - baseLengthFromGen(i-1), x0 + (scale*(i)), y0 - baseLengthFromGen(i));
//        println(scale*(i-1) + " " + baseLengthFromGen(i-1) + " to " + baseLengthFromGen(i));
        
    }
}


// gauss
//
//   Generates Gaussian random numbers.  "threedev" is the width of
//   three standard deviations, or just about out as far as you could
//   reasonably perceive the noise.
//
float gauss(float mean, float threedev)
{
    float x1=0.0, x2, w = 2.0, y1, y2;
    
    while (w >= 1.0) {
        x1 = 2.0 * random(1) - 1.0;
        x2 = 2.0 * random(1) - 1.0;
        w = x1 * x1 + x2 * x2;
    };

    w = sqrt( (-2.0 * log( w ) ) / w );
    y1 = x1 * w;
//    y2 = x2 * w;
    y1 *= threedev / 3;
    y1 += mean;

    return y1;
}


// phototropism_adjust
//
//  Adust the branch angle to simulate bending towards a "sun" that's
//  straight overhead.  
//
void phototropism_adjustment(PVector p, Angle a, boolean usepull)
{
    int dx = int(p.x - arc0.x);
    int dy = int(p.y - arc0.y);
    int dz = int(p.z - arc0.z);
    float mag = dx*dx + dy*dy + dz*dz;
    float pratio = 0.0;
    
    if (mag < arcmagsq) {
        pratio = mag/arcmagsq;
    }
    else {
        pratio = 1.0;
    }

    pratio *= phototrop_mod; // don't go too crazy

    // vector component of where the branching was going
    PVector branchv = cart(1.0 - pratio, a);

    // vector for phototropism: straight up
    PVector photov = new PVector(0, pratio, 0);
    branchv.add(photov);

    // then, adjust with pull vector
    if (usepull) {
        int i = int((p.x + width/2) * float(pullvec_max)/float(width));
        int j = int((p.z + width/2) * float(pullvec_max)/float(width)); // yes, width
        if (i < 0) {
            i = 0;
        }
        if (j < 0) {
            j = 0;
        }
        if (i >= pullvec_max) {
            i = pullvec_max - 1;
        }
        if (j >= pullvec_max) {
            j = pullvec_max - 1;
        }
        PVector pull = new PVector(pullvec[i][j].x, pullvec[i][j].y, pullvec[i][j].z);
        pull.mult(pullvec_mod);
        branchv.add(pull);
    }
    
    spherical(branchv, a);
}

// cart
// spherical
// cart2d
// polar
//
//   Convert an angle to cartesian coordinates, and cartesian to
//   spherical.  cart2d and polar only use theta from the Angle, and
//   x,y from the PVector.
//
PVector cart(float r, Angle a)
{
    PVector p = new PVector();
    
    p.x = r * cos(a.theta) * sin(a.phi);
    p.y = r * sin(a.theta) * sin(a.phi);
    p.z = r * cos(a.phi);

    return p;
}

float spherical(PVector p, Angle a)
{
    float r = p.mag();

    a.theta = atan2(p.y, p.x);
//    a.phi = atan2(sqrt(p.x*p.x + p.y*p.y), p.z);
    a.phi = acos(p.z/r);

    return r;
}

PVector cart2d(float r, Angle a)
{
    PVector p = new PVector();
    p.x = r * cos(-a.theta);
    p.y = r * sin(-a.theta);
    return p;
}

float polar(PVector p, Angle a)
{
    float r = p.mag();
    a.theta = atan2(-p.y, p.x);
    return r;
}

float polar_projection(Angle a)
{
    PVector p = cart(1, a);
    float theta = atan2(-p.y, p.x);
    if (logging) {
        println("(" + nfp(p.x, 3, 0) + ", " + nfp(p.y, 3, 0) + ") -> " + 180*theta/PI + " deg.");
    }
    return theta;
}

float fix_angle(float theta)
{
    if (theta < 0) {
        theta += TWO_PI;
    }
    else if (theta >= TWO_PI) {
        theta -= TWO_PI;
    }
    return theta;
}


// coordstr
//
//   Generate a string like "(mag, theta, phi)".
//
String coordstr(PVector p, Angle a)
{
    return "(" + str(p.mag()) + ", " + str(180*a.theta/PI) + ", " + str(180*a.phi/PI) + ")";
}

String coordstr(PVector p)
{
    return "(" + str(p.x) + ", " + str(p.y) + ", " + str(p.z) + ")";
}

String coordstr(float r, Angle a)
{
    return "(" + str(r) + ", " + str(180*a.theta/PI) + ", " + str(180*a.phi/PI) + ")";
}

// randangle_hole
//
//   Produces bi-variate random numbers, theta and phi in spherical
//   coordinates with a trick.  The angles produced trace out a "circle"
//   on the surface of the unit sphere.  The user can define a minimum
//   angle, giving the circle a hole in the center.  See the
//   randangle_hole program.
//   
//   Initialize with init_randangle_hole before using.
//   
float randangle_hole_amin = 20*PI/180;
float randangle_hole_amax = 60*PI/180;
float randangle_hole_dmax = 0;
float randangle_hole_dmin = 0;
float randangle_hole_blackout_d = 0;

int last_angle_proj_cnt = 0;
float[] last_angle_proj = new float[3];
float angle_proj_sector = 90*PI/180;

void init_randangle_hole(float amin, float amax, float blackout)
{
    // the donut
    PVector vu = new PVector(1, 0, 0);
    PVector vmin = new PVector(cos(amin), sin(amin), 0);
    PVector vmax = new PVector(cos(amax), sin(amax), 0);
    randangle_hole_dmin = vu.dist(vmin);
    randangle_hole_dmax = vu.dist(vmax);
    randangle_hole_amin = amin;
    randangle_hole_amax = amax;

    // blackout distance
    vmax.x = cos(blackout);
    vmax.y = sin(blackout);
    randangle_hole_blackout_d = vu.dist(vmax);
}

Angle randangle_hole(Angle a, int level)
{
    Angle na = new Angle(PI, PI);
    PVector ap = cart(1, a);
    PVector blackout = new PVector(0, 1, 0); // straight down
     
    while (true) {
        na.theta = random(a.theta - randangle_hole_amax, a.theta + randangle_hole_amax);
        na.phi = random(a.phi - randangle_hole_amax, a.phi + randangle_hole_amax);

        PVector nap = cart(1, na);
        float d = ap.dist(nap);

        // require that the numbers fall within the donut
        if (d < randangle_hole_dmin || d > randangle_hole_dmax) {
            continue;
        }
        
        // and that they're not pointed too far at the ground
        if (blackout.dist(nap) < randangle_hole_blackout_d) {
            continue;
        }

        // and that, if this is the trunk, they don't start out on top
        // of each other
        if (level == 0) {
            boolean ok = true;
            float pth = atan2(nap.z, nap.x);
            pth = fix_angle(pth);

            for (int i=0; i<last_angle_proj_cnt; i++) {
                float secmin = (float) last_angle_proj[i] - angle_proj_sector/2;
                float secmax = (float) last_angle_proj[i] + angle_proj_sector/2;
                ok = false;
                if (secmin >= 0 && secmax <= TWO_PI) {
                    if (pth > secmin && pth < secmax) {
                        break;
                    }
                }
                else if (secmin < 0) {
                    // split into [0, secmax] and [secmin, 2*PI]
                    secmin = fix_angle(secmin);
                    if (pth > 0 && pth < secmax) {
                        break;
                    }
                    if (pth < TWO_PI && pth > secmin) {
                        break;
                    }
                }
                else if (secmax > TWO_PI) {
                    // split into [0, secmax] and [secmin, 2*PI]
                    secmax = fix_angle(secmax);
                    if (pth > 0 && pth < secmax) {
                        break;
                    }
                    if (pth < TWO_PI && pth > secmin) {
                        break;
                    }
                }
                ok = true;
//            println("angle of " + pth*180/PI + " is not within sector around" + last_angle_proj[i]*180/PI);
            }
            if (ok) {
                break;
            }
        }
        
        
        // ...and that they don't point back at the middle of the tree
        break;
    }

    return na;
}

void last_angle_shift()
{
    for (int i=1; i<last_angle_proj_cnt; i++) {
        last_angle_proj[i-1] = last_angle_proj[i];
    }
    last_angle_proj_cnt--;
}

void last_angle_push(float f)
{
    while (last_angle_proj_cnt >= last_angle_proj.length) {
        last_angle_shift();
    }
    last_angle_proj[last_angle_proj_cnt++] = f;
}


int grey_from_z(float z)
{
    int gmin = 120;
    int gmax = 255;
    float zmin = -width/2;
    float zmax = width/2;

    z = (z - zmin) / (zmax - zmin);
    z *= (gmax - gmin);
    z += gmin;

    return int(z);
}


////////////////////////////////////////////////////////////////////////
// PLEASE XXX FIX 
////////////////////////////////////////////////////////////////////////

// random_A
//    
//    for when you don't really care about randomness
float[] randA = new float[1000];
int randAi = 0;
float random_A(float x, float y)
{
    randAi = (randAi+1) % randA.length;
    return randA[randAi]*(y-x) + x;
}
void
random_A_init()
{
    int i;

    for (i=0; i<randA.length; i++) {
        randA[i] = random(0, 1);
    }
}

// random_B
//    
//    for when you don't really care about randomness
float[] randB = new float[10000];
int randBi = 0;
float random_B(float x, float y)
{
    randBi = (randBi+1) % randB.length;
    return randB[randBi]*(y-x) + x;
}
void
random_B_init()
{
    int i;

    for (i=0; i<randB.length; i++) {
        randB[i] = random(0, 1);
    }
}
