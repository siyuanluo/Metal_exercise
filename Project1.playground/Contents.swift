import PlaygroundSupport
import MetalKit

guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("GPU is not supported!")
}

let frame = CGRect(x: 0, y: 0, width: 600, height: 400)
let view = MTKView(frame: frame, device: device)
view.clearColor = MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)

// 1
let allocator = MTKMeshBufferAllocator(device: device) // manages the memory for mesh data
// 2
let mdlMesh = MDLMesh(sphereWithExtent: [0.75,0.75,0.75],
                      segments: [100,100],
                      inwardNormals: false,
                      geometryType: .triangles,
                      allocator: allocator)            //creates a sphere and return the segments to mdlMesh
// 3
let mesh = try MTKMesh(mesh: mdlMesh, device: device)  //tell Metal to use the mesh

// make command queue(aim to contribute to paralleling)

guard let commandQueue = device.makeCommandQueue() else {
    fatalError("Could not create a command queue")
}

//shader part

let shader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[ attribute(0) ]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[ stage_in ]]) {
    return vertex_in.position;
}

fragment float4 fragment_main() {
    return float4(1,0,0,1);
}
"""

let library = try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")

//pipeline state & create a descriptor

let descriptor = MTLRenderPipelineDescriptor()
descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
descriptor.vertexFunction = vertexFunction
descriptor.fragmentFunction = fragmentFunction

descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

let pipelineState =
    try device.makeRenderPipelineState(descriptor: descriptor)

//Rendering Part for paralleling

// 1
guard let commandBuffer = commandQueue.makeCommandBuffer(),
      
// give a reference
let descriptor = view.currentRenderPassDescriptor,

// make GPU drawing
let renderEncoder =
    commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
else {fatalError()}

//give the render encoder
renderEncoder.setRenderPipelineState(pipelineState)
renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer
                              , offset: 0, index: 0)

guard let submesh = mesh.submeshes.first else{
    fatalError()
}

renderEncoder.drawIndexedPrimitives(type: .triangle,
                                    indexCount: submesh.indexCount,
                                    indexType: submesh.indexType,
                                    indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0)
// for GPU works

//finish rendering
renderEncoder.endEncoding()

guard let drawable = view.currentDrawable else {
    fatalError()
}

commandBuffer.present(drawable)
commandBuffer.commit()

PlaygroundPage.current.liveView = view

