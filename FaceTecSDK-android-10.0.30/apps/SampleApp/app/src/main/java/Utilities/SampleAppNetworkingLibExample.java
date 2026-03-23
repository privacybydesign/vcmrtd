// Sample networking library class.
//
// Notes:
// - Adding additional logic to this code is not allowed.  Do not add any additional logic outside of what is demonstrated in this Sample.
// - Adding additional asynchronous calls to this code is not allowed.  Only make your own additional asynchronous calls once the FaceTec UI is closed.
// - Adding code that modifies any App UI (Yours or FaceTec's) is not allowed.  Only add code that modifies your own App UI once the FaceTec UI is closed.
package Utilities;

import androidx.annotation.NonNull;

import java.io.IOException;
import java.io.OutputStream;
import java.util.concurrent.TimeUnit;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.RequestBody;
import okio.BufferedSink;
import okio.Okio;

public class SampleAppNetworkingLibExample {
    // This Sample uses the okhttp library, but your integration should use networking libraries
    // and constructs that your organization generally uses to communicate from client to server.
    private static OkHttpClient _apiClient = null;

    private static OkHttpClient createApiClient() {
        return new OkHttpClient.Builder()
                .callTimeout(120, TimeUnit.SECONDS)
                .connectTimeout(120, TimeUnit.SECONDS)
                .readTimeout(120,TimeUnit.SECONDS)
                .writeTimeout(120, TimeUnit.SECONDS)
                .build();
    }

    public static synchronized OkHttpClient getApiClient() {
        if (_apiClient == null) {
            _apiClient = createApiClient();
        }
        return _apiClient;
    }
}

/*
 * Implementation of RequestBody that allows upload progress to be retrieved
 */
class ProgressRequestBody extends RequestBody {
    private final RequestBody requestBody;
    private final Listener listener;

    ProgressRequestBody(RequestBody requestBody, Listener listener) {
        this.requestBody = requestBody;
        this.listener = listener;
    }

    @Override
    public MediaType contentType() {
        return requestBody.contentType();
    }

    @Override
    public long contentLength() throws IOException {
        return requestBody.contentLength();
    }

    @Override
    public void writeTo(BufferedSink sink) throws IOException {
        ProgressStream progressStream = new ProgressStream(sink.outputStream(), contentLength());
        BufferedSink progressSink = Okio.buffer(Okio.sink(progressStream));
        requestBody.writeTo(progressSink);
        progressSink.flush();
    }

    protected final class ProgressStream extends OutputStream {
        private final OutputStream stream;
        private final long totalBytes;
        private long bytesSent;

        ProgressStream(OutputStream stream, long totalBytes) {
            this.stream = stream;
            this.totalBytes = totalBytes;
        }

        @Override
        public void write(@NonNull byte[] b, int off, int len) throws IOException {
            this.stream.write(b, off, len);
            this.bytesSent += Math.min(len, b.length);
            listener.onUploadProgressChanged(this.bytesSent, this.totalBytes);
        }

        @Override
        public void write(int b) throws IOException {
            this.stream.write(b);
            this.bytesSent += 1;
            listener.onUploadProgressChanged(this.bytesSent, this.totalBytes);
        }
    }

    interface Listener {
        void onUploadProgressChanged(long bytesWritten, long totalBytes);
    }
}