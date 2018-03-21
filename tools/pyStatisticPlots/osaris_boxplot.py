import matplotlib.pyplot as plt
import matplotlib.patches as patches
import matplotlib.dates as mdates
import pandas as pd
import numpy as np
from datetime import datetime


def customized_box_plot(percentiles, redraw = True, *args, **kwargs):
    """
    Generates a customized boxplot based on the given percentile values
    """

    years = mdates.YearLocator()  # every year
    months = mdates.MonthLocator()  # every month
    yearsFmt = mdates.DateFormatter('%Y')
    monthsFmt = mdates.DateFormatter('%m')

    fig, ax = plt.subplots()

    ax.set_title("Mountain range")
    ax.set_xlabel("Date")
    ax.set_ylabel("Coherence")

    first_date = pd.to_datetime(percentiles[0][6], format='%Y%m%d')
    last_date = pd.to_datetime(percentiles[-1][6], format='%Y%m%d')

    min_date = datetime(first_date.year, first_date.month, 1)
    max_date = datetime(last_date.year + (int(last_date.month / 12)), ((last_date.month % 12) + 1), 1)

    # timespan = pd.date_range(min_date, max_date, freq='M')

    n_box = last_date - first_date
    n_box = np.int(n_box / np.timedelta64(1, 'D'))
    box_plot = ax.boxplot([[-9, -4, 2, 4, 9], ] * n_box, *args, **kwargs)

    min_y, max_y = float('inf'), -float('inf')

    xbox_last_max = first_date
    N = len(percentiles)
    box_colors = ['hsl(' + str(h) + ',50%' + ',50%)' for h in np.linspace(0, 360, N)]

    for box_no, pdata in enumerate(percentiles):
        if len(pdata) == 8:
            (q1_start, q2_start, q3_start, q4_start, q4_end, start_date, end_date, days) = pdata
        elif len(pdata) == 5:
            (q1_start, q2_start, q3_start, q4_start, q4_end) = pdata
            # fliers_xy = None
        else:
            raise ValueError("Percentile arrays for customized_box_plot must have either 5 or 6 values")

        days = np.int(days)

        # Box
        # print(box_plot['boxes'][box_no].get_xdata())
        xbox = box_plot['boxes'][box_no].get_xdata()
        ybox = box_plot['boxes'][box_no].get_ydata()
        xbox_ll = xbox_last_max  # xbox[0] - (0.01 * days)
        xbox_lr = xbox_last_max + np.timedelta64(days, 'D')
        xbox_ur = xbox_last_max + np.timedelta64(days, 'D')
        xbox_ul = xbox_last_max  # xbox[3] - (0.01 * days)
        xbox_ll2 = xbox_last_max  # xbox[4] - (0.01 * days)



        box_plot['boxes'][box_no].set_xdata([xbox_ll, xbox_lr, xbox_ur, xbox_ul, xbox_ll2])
        path = box_plot['boxes'][box_no].get_path()
        path.vertices[0][1] = q2_start
        path.vertices[1][1] = q2_start
        path.vertices[2][1] = q4_start
        path.vertices[3][1] = q4_start
        path.vertices[4][1] = q2_start

        print(ybox)
        # Add filled box
        x_coord = mdates.date2num(xbox_last_max)
        y_coord = q2_start
        rect_width = mdates.date2num(xbox_ur) - mdates.date2num(xbox_last_max)
        rect_height = q4_start - q2_start
        ax.add_patch(
            patches.Rectangle(
                (x_coord, y_coord),  # (x,y)        xbox_last_max, ybox[0]
                rect_width,  # width         np.timedelta64(days, 'D')
                rect_height,  # height       ybox[1] - ybox[0]
                alpha=0.5,
                facecolor="#AAAAAA"
            )
        )

        xbox_last_max = xbox_ur

        # Prepare caps and whiskers
        cap_offset = np.timedelta64(np.int(0.1 * days), 'D')
        whisker_offset = np.timedelta64(0.5 * (xbox_lr - xbox_ll), 'D')
        xcap_l = xbox_ll + cap_offset
        xcap_r = xbox_lr - cap_offset
        xwhisker = xbox_ll + whisker_offset

        # Lower cap
        box_plot['caps'][2*box_no].set_ydata([q1_start, q1_start])
        box_plot['caps'][2 * box_no].set_xdata([xcap_l, xcap_r])

        # Lower whiskers
        box_plot['whiskers'][2 * box_no].set_ydata([q1_start, q2_start])
        box_plot['whiskers'][2 * box_no].set_xdata([xwhisker, xwhisker])

        # Higher cap
        box_plot['caps'][2 * box_no + 1].set_ydata([q4_end, q4_end])
        box_plot['caps'][2 * box_no + 1].set_xdata([xcap_l, xcap_r])

        # Higher whiskers
        box_plot['whiskers'][2 * box_no + 1].set_ydata([q4_start, q4_end])
        box_plot['whiskers'][2 * box_no + 1].set_xdata([xwhisker, xwhisker])

        # Median
        box_plot['medians'][box_no].set_ydata([q3_start, q3_start])
        box_plot['medians'][box_no].set_xdata([xbox_ul, xbox_ur])

        min_y = min(q1_start, min_y)
        max_y = max(q4_end, max_y)

        # The y axis is rescaled to fit the new box plot completely with 10%
        # of the maximum value at both ends
        ax.set_ylim([min_y*1.1, max_y*1.1])

    print(box_plot)
    i = 0
    #for patch in range(1, len(box_plot)):
    #    patch.set(facecolor=box_colors[i])
    # box_plot['boxes'].setp(facecolor=)

    # Format the grid
    ax.set_xlim(min_date, max_date)
    ax.grid(True)
    ax.grid(b=True, which='minor', color='#CCCCCC', linestyle=':')
    ax.grid(b=True, which='major', color='#CCCCCC', linestyle=':')
    ax.set_axisbelow(True)
    ax.tick_params(axis='x', which='major', pad=16)

    fig.autofmt_xdate()

    # format the ticks
    ax.xaxis.set_major_locator(years)
    ax.xaxis.set_major_formatter(yearsFmt)
    ax.xaxis.set_minor_locator(months)
    ax.xaxis.set_minor_formatter(monthsFmt)

    plt.xticks(rotation=0, fontweight='bold', ha='center')

    # If redraw is set to true, the canvas is updated.
    if redraw:
        ax.figure.canvas.draw()

    plt.show()
    # return box_plot


csv_dataset = pd.read_csv('./data/Golubin-_.grd.csv', dtype={'Days': np.int32})
# ./display_amp_ll-F3.csv
# ./corr_ll-F3.csv
minimum = csv_dataset['Min']
low_box = csv_dataset['Median'] - csv_dataset['Scale']
median = csv_dataset['Median']
up_box = csv_dataset['Median'] + csv_dataset['Scale']
maximum = csv_dataset['Max']
start_date = csv_dataset['Start date']
end_date = csv_dataset['End date']
days = csv_dataset['Days']

percentiles = np.array([minimum, low_box, median, up_box, maximum, start_date, end_date, days])
percentiles = percentiles.T

b = customized_box_plot(percentiles)
