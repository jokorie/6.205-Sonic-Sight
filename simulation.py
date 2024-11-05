import numpy as np
from scipy.fft import fft
import matplotlib.pyplot as plt


# Global Constants
SAMPLING_RATE = 100000
PULSE_FREQUENCY = 40000
SPEED_OF_SOUND = 343
TIME_DELAY = .02 # in seconds
OBJECT_VELOCITY = 20 # m/s


# Phased Array Simulation
# Generates an ultrasonic pulse
def generate_pulse(frequency=PULSE_FREQUENCY, duration=0.001, sampling_rate=SAMPLING_RATE):
    t = np.linspace(0, duration, int(sampling_rate * duration), endpoint=False)
    pulse = np.sin(2 * np.pi * frequency * t)
    return pulse


def generate_doppler_shifted_pulse(input_signal, object_velocity=OBJECT_VELOCITY, base_frequency=PULSE_FREQUENCY, speed_of_sound=SPEED_OF_SOUND, sampling_rate=100000):
    """
    Takes in an input signal and returns a frequency-modulated version of the pulse
    based on Doppler shift due to object movement.


    Parameters:
    - input_signal: ndarray, the original signal to be modulated.
    - base_frequency: float, the base frequency of the wave being transmitted (in Hz).
    - object_velocity: float, velocity of the object moving through the path (in m/s).
    - speed_of_sound: float, speed of sound in the medium (in m/s).
    - sampling_rate: int, the rate at which the signal is sampled (samples per second).


    Returns:
    - modulated_signal: ndarray, the frequency-modulated version of the input signal.
    """
    # Calculate the Doppler shift frequency caused by the object's velocity
    doppler_shift = (object_velocity / speed_of_sound) * base_frequency
   
    # Determine effective frequency over time
    if object_velocity > 0:
        # Moving towards the observer, frequency increases
        effective_frequency = base_frequency + doppler_shift
    else:
        # Moving away from the observer, frequency decreases
        effective_frequency = base_frequency - abs(doppler_shift)
   
    # Generate time array
    t = np.linspace(0, len(input_signal) / sampling_rate, len(input_signal), endpoint=False)
   
    # Calculate the instantaneous phase with Doppler-modulated frequency
    instantaneous_phase = 2 * np.pi * effective_frequency * t


    # Generate the modulated signal by changing the phase of the original signal
    modulated_signal = np.sin(instantaneous_phase) * np.abs(input_signal)  # Retain original amplitude
   
    return modulated_signal


# Frequency Distortion Function
# Distorts the frequency of the wave to simulate environmental or motion effects
def distort_frequency(signal, sampling_rate=SAMPLING_RATE, distortion_frequency=1000):
    # Add a modulation to the original signal by distorting the frequency
    t = np.linspace(0, len(signal) / sampling_rate, len(signal), endpoint=False)
    distortion = np.sin(2 * np.pi * distortion_frequency * t)
    distorted_signal = signal * (1 + 0.1 * distortion)  # Modulate signal with a small distortion
    return distorted_signal # amplitude modulation




# Analog-to-Digital Converter (ADC) Simulation
# Converts the generated analog pulse into digital values
def adc_simulation(analog_signal, bit_resolution=16):
    max_val = 2**(bit_resolution - 1) - 1
    digital_signal = np.round(analog_signal * max_val).astype(int)
    return digital_signal


# Time-of-Flight (ToF) Calculation Module
# Calculates the distance based on time delay
def calculate_distance(time_delay, speed_of_sound=SPEED_OF_SOUND):
    distance = (speed_of_sound * time_delay) / 2  # Divide by 2 for round trip
    return distance


# FFT Analysis for Doppler Shift
# Performs FFT on the signal to detect frequency shifts
def doppler_shift_analysis(signal, sampling_rate=SAMPLING_RATE):
    window = np.hanning(len(signal))
    windowed_signal = signal * window
    fft_result = fft(windowed_signal)
    freqs = np.fft.fftfreq(len(signal), 1 / sampling_rate)
    positive_freqs = freqs[freqs >= 0]
    positive_fft_magnitude = np.abs(fft_result)[freqs >= 0]
    return positive_freqs, positive_fft_magnitude


# Velocity Calculation Module
# Calculates velocity using Doppler frequency shift
def calculate_velocity(doppler_frequency, wave_frequency=PULSE_FREQUENCY, speed_of_sound=SPEED_OF_SOUND):
    return (doppler_frequency / wave_frequency) * speed_of_sound


if __name__ == "__main__":
    # EMIT WAVE
    analog_pulse = generate_pulse()


    # FREQ OF WAVE DISTORTED BY OBJECT
    velocity_distorted_pulse = generate_doppler_shifted_pulse(analog_pulse)


    # AMPL OF WAVE DISTORTED BY ENVIRORNMENT
    final_distorted_pulse = distort_frequency(velocity_distorted_pulse, sampling_rate=SAMPLING_RATE)


    # RECEIVE DISTORTED WAVE
    digital_signal = adc_simulation(final_distorted_pulse)
   
    # CALCULATE THE DISTANCE
    distance = calculate_distance(TIME_DELAY)


    # Perform FFT analysis
    freqs, fft_magnitude = doppler_shift_analysis(digital_signal, sampling_rate=SAMPLING_RATE)


    # FIND THE PEAK FREQUENCY (which should just be PULSE_FREQUENCY + Doppler Shift)
    peak_index = np.argmax(fft_magnitude)
    peak_frequency = freqs[peak_index]


    # Calculate Doppler frequency shift and velocity
    doppler_frequency_shift = peak_frequency - PULSE_FREQUENCY  # Assuming the original pulse frequency is 40 kHz
    velocity = calculate_velocity(doppler_frequency_shift)


    print(f"Doppler Frequency Shift: {doppler_frequency_shift} Hz")
    print(f"Calculated Velocity: {velocity:.2f} m/s")


    # Visualization
    # Plotting the distance and velocity results
    distances = [calculate_distance(td) for td in np.linspace(0.01, 0.05, 50)]
    velocities = [calculate_velocity(df) for df in np.linspace(1, 20, 50)]


    plt.figure(figsize=(10, 6))
    plt.subplot(2, 1, 1)
    plt.plot(distances)
    plt.title('Distance over Time')
    plt.xlabel('Time Step')
    plt.ylabel('Distance (m)')
    plt.grid(True)


    plt.subplot(2, 1, 2)
    plt.plot(velocities)
    plt.title('Velocity over Time')
    plt.xlabel('Time Step')
    plt.ylabel('Velocity (m/s)')
    plt.grid(True)


    plt.tight_layout()
    plt.savefig('simulation_plot.png')






    # Plot Frequency Spectrum to visualize effect of distortion
    # side bands appear. Which is natural
    plt.figure(figsize=(10, 6))
    plt.plot(freqs, fft_magnitude)
    plt.title('Frequency Spectrum of Distorted Signal')
    plt.xlabel('Frequency (Hz)')
    plt.ylabel('Magnitude')
    plt.xlim(0, PULSE_FREQUENCY * 1.25)  # Limit x-axis to a reasonable range (e.g., slightly above pulse frequency)
    plt.grid(True)


    plt.tight_layout()
    plt.savefig('frequency_spectrum.png')




    # Plot Time-Domain Signal of Distorted Pulse
    plt.figure(figsize=(10, 4))
    t = np.linspace(0, len(final_distorted_pulse) / SAMPLING_RATE, len(final_distorted_pulse))
    plt.plot(t, final_distorted_pulse)
    plt.title('Time-Domain Signal of Distorted Pulse')
    plt.xlabel('Time (s)')
    plt.ylabel('Amplitude')
    plt.grid(True)
    plt.tight_layout()
    plt.savefig('time_domain_distorted_pulse.png')



