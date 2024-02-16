//
//  NBTFileReader.swift
//
//
//  Created by Ivan Podvorniy on 07.08.2021.
//

import NIO
import CompressNIO

public class NBTFile {
    let io: NonBlockingFileIO
    var byteBuffer: ByteBuffer
    let bufferAllocator: ByteBufferAllocator
    
    public init(io: NonBlockingFileIO, bufferAllocator: ByteBufferAllocator) throws {
        self.io = io
        self.bufferAllocator = bufferAllocator
        self.byteBuffer = bufferAllocator.buffer(capacity: 0)
    }
    
    public func read(path: String, eventLoop: EventLoop, gzip: Bool = true) -> EventLoopFuture<NBT> {
        self.byteBuffer = bufferAllocator.buffer(capacity: 0)
        return io.openFile(path: path, eventLoop: eventLoop).flatMap { fileHandle, fileRegion in
            return self.io.readChunked(fileRegion: fileRegion, allocator: self.bufferAllocator, eventLoop: eventLoop) { nextPart in
                self.byteBuffer.writeImmutableBuffer(nextPart)
                return eventLoop.makeSucceededVoidFuture()
            }.flatMapThrowing {
                try fileHandle.close()
                return try NBT(readFrom: &self.byteBuffer, gzip: gzip)
            }
        }
    }
    
    public func write(nbt: inout NBT, path: String, eventLoop: EventLoop, gzip: Bool = true) throws -> EventLoopFuture<Void> {
        self.byteBuffer = self.bufferAllocator.buffer(capacity: 0)
        try nbt.write(to: &self.byteBuffer)
        return io.openFile(path: path, eventLoop: eventLoop).flatMapThrowing { fileHandle, fileRegion in
            return self.io.write(fileHandle: fileHandle, buffer: self.byteBuffer, eventLoop: eventLoop)
        }.flatMap { $0 }
    }
}
