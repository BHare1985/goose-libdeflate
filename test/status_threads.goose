// Proves the last-error slot is thread-local: a worker's success or failure
// must not replace the caller thread's recorded failure.
import deflate from "..";
import std;

thread_fn successful_call() {
    var packed: u8[>..] = [];
    let ok = deflate::compress(packed, "thread-local success", deflate::Format.Gzip);
    qput(ok);
    qput(deflate::status());
}

thread_fn failing_call() {
    var plain: u8[>..] = [];
    let ok = deflate::decompress(plain, "not a gzip stream", deflate::Format.Gzip);
    qput(ok);
    qput(deflate::status());
}

fn main() {
    var plain: u8[>..] = [];
    let main_ok = deflate::decompress(plain, "not a gzip stream", deflate::Format.Gzip);
    assert(!main_ok && deflate::status() == deflate::Status.BadData);

    let success_id = thread_spawn(successful_call);
    thread_wait(success_id);
    assert(qget<bool>());
    assert(qget<deflate::Status>() == deflate::Status.Ok);
    assert(deflate::status() == deflate::Status.BadData);

    let failure_id = thread_spawn(failing_call);
    thread_wait(failure_id);
    assert(!qget<bool>());
    assert(qget<deflate::Status>() == deflate::Status.BadData);
    assert(deflate::status() == deflate::Status.BadData);

    print("thread-local status: ok");
}
