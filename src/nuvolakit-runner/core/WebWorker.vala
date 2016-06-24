/*
 * Copyright 2014-2016 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer. 
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution. 
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


namespace Nuvola
{

public interface WebWorker: GLib.Object, JSExecutor
{
	public abstract Variant? send_message(string name, Variant? params) throws GLib.Error;
	
	public void disable_gstreamer()
	{
		try
		{
			send_message("disable_gstreamer", null);
		}
		catch (GLib.Error e)
		{
			warning("Failed to send message 'disable_gstreamer': %s", e.message);
		}
	}
}

public class RemoteWebWorker: GLib.Object, JSExecutor, WebWorker
{
	private ApiBus abus;
	
	public RemoteWebWorker(ApiBus abus)
	{
		this.abus = abus;
	}
	
	public Variant? send_message(string name, Variant? params) throws GLib.Error
	{
		if (abus.web_worker == null)
			throw new Diorite.MessageError.NOT_READY("Web worker process is not ready yet");
		
		return abus.web_worker.send_message(name, params);
	}
	
	public void call_function(string name, ref Variant? params) throws GLib.Error
	{
		var data = new Variant("(smv)", name, params);
		params = send_message("call_function", data);
	}
}

} // namespace Nuvola
