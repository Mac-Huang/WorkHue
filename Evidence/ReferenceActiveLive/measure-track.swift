import AppKit
import Darwin
setbuf(stdout, nil)
let path = CommandLine.arguments[1]
let rep = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: path)))!
func rgb(_ x: Int, _ y: Int) -> [Int] {
 let c = rep.colorAt(x:x, y:y)!
 return [c.redComponent,c.greenComponent,c.blueComponent].map { Int(($0*255).rounded()) }
}
func bounds(_ name:String,_ xs:Range<Int>,_ ys:Range<Int>,_ test:([Int],Int,Int)->Bool) {
 var minX=9999,minY=9999,maxX=0,maxY=0
 for y in ys {for x in xs {if test(rgb(x,y),x,y) {minX=min(minX,x);minY=min(minY,y);maxX=max(maxX,x);maxY=max(maxY,y)}}}
 print(name, [minX,minY,maxX+1,maxY+1], "points",[minX,minY,maxX+1,maxY+1].map{Double($0)/3})
}
func blue(_ c:[Int])->Bool { c[2]>c[0]+15 && c[2]>c[1]+3 }
func gray(_ c:[Int])->Bool { c.min()!>80 && c.max()!<205 && c.max()!-c.min()!<10 }
func whiteInCore(_ c:[Int],_ x:Int,_ y:Int)->Bool { c.min()!>249 && pow(Double(x-645),2)+pow(Double(y-1460),2)<pow(295.0,2) }
let ys=(950..<1850).filter {blue(rgb(645,$0))}
print("outerVerticalPixels",ys.min()!,ys.max()!+1,"points",Double(ys.min()!)/3,Double(ys.max()!+1)/3)
let xs=(0..<1290).filter {blue(rgb($0,1460))}
print("outerHorizontalPixels",xs.min()!,xs.max()!+1,"points",Double(xs.min()!)/3,Double(xs.max()!+1)/3)
bounds("INInk",400..<890,1270..<1500,whiteInCore)
bounds("timerInk",400..<890,1500..<1660,whiteInCore)
bounds("StartedInk",350..<950,1840..<1950,{c,_,_ in gray(c)})
bounds("workloadInk",450..<850,1950..<2070,{c,_,_ in blue(c)})

bounds("lineTabInk",800..<1000,2500..<2670,{c,_,_ in c.max()!-c.min()!>50})
