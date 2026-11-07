import AppKit
let rep=NSBitmapImageRep(data:try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1])))!
func grayRing(_ x:Int,_ y:Int)->Bool {let c=rep.colorAt(x:x,y:y)!;let a=[c.redComponent,c.greenComponent,c.blueComponent].map{Int(($0*255).rounded())};return a.min()!>20 && a.max()!<90 && a.max()!-a.min()!<10}
var runs:[[Int]]=[];var start:Int?
for y in 700..<2400 {if grayRing(645,y) {if start==nil{start=y}} else if let s=start {if y-s>10 {runs.append([s,y])};start=nil}}
print("centerColumnGrayRuns",runs)
if runs.count>=2 {let center=(runs[0][0]+runs[1][1])/2;print("ringCenterY",Double(center)/3);let xs=(0..<1290).filter{grayRing($0,center)};if let first=xs.min(),let last=xs.max(){print("ringHorizontalBounds",Double(first)/3,Double(last+1)/3)}}
