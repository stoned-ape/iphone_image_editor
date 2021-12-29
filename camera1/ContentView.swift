//
//  ContentView.swift
//  camera1
//
//  Created by Apple1 on 3/29/21.
//
import SwiftUI
import MetalKit
import Metal
import Dispatch
import ARKit
import RealityKit
import simd



typealias float=Float
typealias double=Double
typealias int=Int
typealias bool=Bool
typealias string=String
typealias char=Character

func rand()->float{
    return float.random(in: 0...1)
}
func sizeof<T:Any>(_ a:T)->int{
    return MemoryLayout.size(ofValue:a)
}
func time()->float{
    return float(ProcessInfo.processInfo.systemUptime)
}

let bytes_per_image=4032*3024*4*4


struct ui_bindings{
    var h:Binding<float>
    var s:Binding<float>
    var b:Binding<float>
    var off:Binding<float>
    var ed:Binding<bool>
    var sh:Binding<bool>
    var bl:Binding<bool>
    var th:Binding<bool>
    var ng:Binding<bool>
    var yc:Binding<bool>
    var ex:Binding<bool>
    var rd:Binding<bool>
}


struct ContentView:View{
    @State var h:float=0
    @State var s:float=1
    @State var b:float=1
    @State var off:float=0
    @State var ed=false
    @State var sh=false
    @State var bl=false
    @State var th=false
    @State var ng=false
    @State var yc=false
    @State var ex=false
    @State var rd=false
    var body:some View{
        let maincamview=cameraview(
            ub:ui_bindings(h: $h,s: $s, b: $b, off: $off,
                           ed:$ed,sh:$sh,bl:$bl,th:$th,ng:$ng,yc:$yc,
                           ex:$ex,rd:$rd)
        )
        let mainarview=arview(del:maincamview.del)
        
        VStack{
            ZStack{
                maincamview
                Spacer()
                mainarview
                maincamview
            }
            HStack{
                HStack{
                    
                    Spacer()
                    Toggle("ed",isOn:$ed);Spacer()
                    Toggle("sh",isOn:$sh);Spacer()
                    Toggle("bl",isOn:$bl);Spacer()
                }
                HStack{
                    Toggle("th",isOn:$th);Spacer()
                    Toggle("ng",isOn:$ng);Spacer()
                    Toggle("yc",isOn:$yc);Spacer()
                }
            }
            HStack{
                Spacer()
                Toggle("ex",isOn:$ex);Spacer()
                Toggle("rd",isOn:$rd);Spacer()
            }
            HStack{
                Spacer()
                VStack{
                    Slider(value:$h,in:0...1){Text("hue")}
                    Slider(value:$s,in:0...2){Text("sat")}
                    Slider(value:$b,in:0...5){Text("brg")}
                    Slider(value:$off,in:0...1){Text("off")}
                }
                Spacer()
            }
        }
    
    }
}



struct cameraview:UIViewRepresentable{
    let mtkview=MTKView()
    var del=renderer()
    var ub:ui_bindings
    func makeUIView(context: Context)->some UIView{
        mtkview.delegate=del
        mtkview.device=del.device
        mtkview.framebufferOnly=false
        
        del.ub=ub
        return mtkview
    }
    func updateUIView(_ uiView: UIViewType, context: Context){}
    
}

struct arview:UIViewRepresentable{
    let arview=ARView(frame:.zero)
    let anchor=AnchorEntity()
    let del:renderer
    func makeUIView(context: Context)->some UIView{
        arview.scene.anchors.append(anchor)
        arview.session.delegate=del
        return arview
    }
    func updateUIView(_ uiView: UIViewType, context: Context){}
}






class renderer:NSObject,MTKViewDelegate,ARSessionDelegate{
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLComputePipelineState
    var image: MTLTexture
    var prev_frame: MTLTexture
    var frameCount:int=0
    var capturedImageTextureCache:CVMetalTextureCache!
    var tex0:MTLTexture?
    var tex1:MTLTexture?
    var pt:float=0
    var dt:float=0
    var uni:uniforms?
    var ub:ui_bindings?
    override init(){
        device=MTLCreateSystemDefaultDevice()!
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        capturedImageTextureCache = textureCache
        commandQueue=device.makeCommandQueue()!
        let textureLoader = MTKTextureLoader(device: device)
        let url = Bundle.main.url(forResource: "black", withExtension: "png")!
        image = try! textureLoader.newTexture(URL: url, options: [:])
        prev_frame = try! textureLoader.newTexture(URL: url, options: [:])
        let library=device.makeDefaultLibrary()!
        let function=library.makeFunction(name: "compute")!
        pipelineState=try! device.makeComputePipelineState(function: function)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize){}
    func dt_update(){
        frameCount+=1
        let now=time()
        dt=now-pt
        pt=now
    }
    func draw(in view: MTKView){
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder(),
              let drawable = view.currentDrawable else {
            return
        }
        commandEncoder.setComputePipelineState(pipelineState)
        setuniforms(view)
        let buf=device.makeBuffer(bytes:&uni!,length:sizeof(uni!),options:[])
        commandEncoder.setBuffer(buf,offset:0,index:0)
        
        
        commandEncoder.setTexture(prev_frame, index: 3)

        if tex0 != nil{
            commandEncoder.setTexture(tex0!, index: 0)
            commandEncoder.setTexture(tex1!, index: 1)
        }else{
            commandEncoder.setTexture(image, index: 0)
            commandEncoder.setTexture(image, index: 1)
        }
        commandEncoder.setTexture(drawable.texture, index: 2)
        var w = pipelineState.threadExecutionWidth
        var h = pipelineState.maxTotalThreadsPerThreadgroup / w
//        print("w: \(view.drawableSize.width) h: \(view.drawableSize.height)")
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        w=Int(view.drawableSize.width)/w
        h=Int(view.drawableSize.height)/h
        commandEncoder.dispatchThreadgroups(
            MTLSize(width:w,height:h,depth:1),
            threadsPerThreadgroup:threadsPerThreadgroup)
        commandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        dt_update()
        print("frame")
        prev_frame=drawable.texture
    }
    func createTexture(_ pixelBuffer: CVPixelBuffer,_ pixelFormat: MTLPixelFormat,_ plane:int)->MTLTexture?{
        let w=CVPixelBufferGetWidthOfPlane(pixelBuffer,plane)
        let h=CVPixelBufferGetHeightOfPlane(pixelBuffer,plane)
        var texture: CVMetalTexture? = nil
        CVMetalTextureCacheCreateTextureFromImage(nil,
                    capturedImageTextureCache, pixelBuffer, nil, pixelFormat,
                    w,h,plane,&texture)
        return CVMetalTextureGetTexture(texture!)
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame){
        print("arframe")
        tex0=createTexture(frame.capturedImage,ub!.yc.wrappedValue ? .b5g6r5Unorm : .r8Unorm,0)
        tex1=createTexture(frame.capturedImage,ub!.yc.wrappedValue ? .b5g6r5Unorm : .rg8Unorm,1)
    }
    func setuniforms(_ view: MTKView){
        let iRes=simd_uint2(UInt32(view.drawableSize.width),
                            UInt32(view.drawableSize.height))
        
        func bool2i32(_ b:Binding<bool>)->Int32{
            return b.wrappedValue ? Int32(1):Int32(0)
        }
        uni=uniforms(iTime: time(),
                     iRes: iRes,
                     frameCount: Int32(frameCount),
                     dt:dt,
                     ed:bool2i32(ub!.ed),
                     sh:bool2i32(ub!.sh),
                     bl:bool2i32(ub!.bl),
                     th:bool2i32(ub!.th),
                     ng:bool2i32(ub!.ng),
                     yc:bool2i32(ub!.yc),
                     ex:bool2i32(ub!.ex),
                     rd:bool2i32(ub!.rd),
                     hsb:simd_float3(ub!.h.wrappedValue,ub!.s.wrappedValue,ub!.b.wrappedValue),
                     offset:ub!.off.wrappedValue
        )
    }
}


//preview pixel format types [875704422, 875704438, 1111970369]

//w: 750 h: 1294
//7619005 bytes

//w: 4032 h: 3024

//gpu kernel w: 32 h: 16
//gpu has 32 cores which run in parallel
//each core runs 16 threads concurrently
//the kernel slides across the entire grid running each block in series
//it takes 1/10th of a second to get pixel data from the camera with
//the current method.

//1919379252

//<CVPixelBuffer 0x281972ee0 width=1920 height=1440 pixelFormat=420f iosurface=0x282d66a70 planes=2>
//<Plane 0 width=1920 height=1440 bytesPerRow=1920>
//<Plane 1 width=960 height=720 bytesPerRow=1920>
//<attributes={
//    PixelFormatDescription =     {
//        BitsPerComponent = 8;
//        ComponentRange = FullRange;
//        ContainsAlpha = 0;
//        ContainsGrayscale = 0;
//        ContainsRGB = 0;
//        ContainsYCbCr = 1;
//        FillExtendedPixelsCallback = {length = 24, bytes = 0x00000000000000002084d5a8010000000000000000000000};
//        IOSurfaceCoreAnimationCompatibility = 1;
//        IOSurfaceOpenGLESFBOCompatibility = 1;
//        IOSurfaceOpenGLESTextureCompatibility = 1;
//        OpenGLESCompatibility = 1;
//        PixelFormat = 875704422;
//        Planes =         (
//                        {
//                BitsPerBlock = 8;
//                BlackBlock = {length = 1, bytes = 0x00};
//            },
//                        {
//                BitsPerBlock = 16;
//                BlackBlock = {length = 2, bytes = 0x8080};
//                HorizontalSubsampling = 2;
//                VerticalSubsampling = 2;
//            }
//        );
//    };
//} propagatedAttachments={
//    CVImageBufferColorPrimaries = "ITU_R_709_2";
//    CVImageBufferTransferFunction = "ITU_R_709_2";
//    CVImageBufferYCbCrMatrix = "ITU_R_601_4";
//    MetadataDictionary =     {
//        ExposureTime = "0.016603";
//        NormalizedSNR = "10.98133352723569";
//        SNR = "11.54190799924056";
//        SensorID = 771;
//    };
//} nonPropagatedAttachments={
//}>














//<CVPixelBuffer 0x280c5ad00 width=1000 height=750 pixelFormat=420f iosurface=0x283f5c180 planes=2>
//<Plane 0 width=1000 height=750 bytesPerRow=1024>
//<Plane 1 width=500 height=375 bytesPerRow=1024>
//<attributes={
//    PixelFormatDescription =     {
//        BitsPerComponent = 8;
//        ComponentRange = FullRange;
//        ContainsAlpha = 0;
//        ContainsGrayscale = 0;
//        ContainsRGB = 0;
//        ContainsYCbCr = 1;
//        FillExtendedPixelsCallback = {length = 24, bytes = 0x00000000000000002084d5a8010000000000000000000000};
//        IOSurfaceCoreAnimationCompatibility = 1;
//        IOSurfaceOpenGLESFBOCompatibility = 1;
//        IOSurfaceOpenGLESTextureCompatibility = 1;
//        OpenGLESCompatibility = 1;
//        PixelFormat = 875704422;
//        Planes =         (
//                        {
//                BitsPerBlock = 8;
//                BlackBlock = {length = 1, bytes = 0x00};
//            },
//                        {
//                BitsPerBlock = 16;
//                BlackBlock = {length = 2, bytes = 0x8080};
//                HorizontalSubsampling = 2;
//                VerticalSubsampling = 2;
//            }
//        );
//    };
//} propagatedAttachments={
//    CVImageBufferColorPrimaries = "P3_D65";
//    CVImageBufferTransferFunction = "ITU_R_709_2";
//    CVImageBufferYCbCrMatrix = "ITU_R_601_4";
//} nonPropagatedAttachments={
//}>

//<CVPixelBuffer 0x28045a120 width=4032 height=3024 bytesPerRow=8064 pixelFormat=rgg4 iosurface=0x28375dba0 attributes={
//    PixelFormatDescription =     {
//        BitsPerBlock = 16;
//        BitsPerComponent = 8;
//        ContainsAlpha = 0;
//        ContainsGrayscale = 0;
//        ContainsRGB = 1;
//        ContainsYCbCr = 0;
//        FillExtendedPixelsCallback = {length = 24, bytes = 0x0000000000000000a479d5a8010000000000000000000000};
//        PixelFormat = 1919379252;
//    };
//} propagatedAttachments={
//    CVImageBufferChromaLocationTopField = Center;
//} nonPropagatedAttachments={
//}>


